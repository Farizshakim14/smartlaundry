/*
 * ESP32 LAUNDRY MONITOR - UNIT 1 (Mesin 1 & 2) - v3.8 TANG AMPERE CALIBRATION
 * Server: 192.168.18.15:3000 (Local Server)
 * 
 * CHANGELOG v3.8 Tang Ampere Calibration:
 * - ADDED: Command tanga1/tanga2 <amps> untuk kalibrasi langsung dengan referensi tang ampere
 * - ADDED: Command err1/err2 <amps> untuk cek error vs tang ampere
 * - ADDED: Command qcal <A1> <A2> untuk kalibrasi cepat kedua channel
 * - ADDED: Verifikasi otomatis setelah kalibrasi dengan hitung error percentage
 * - ADDED: Recalibrate zero offset otomatis sebelum setiap pengukuran kalibrasi
 * - ADDED: 5x sample dengan delay 500ms untuk stabilitas maksimal
 * - ADDED: Minimum arus 0.3A untuk validasi kalibrasi
 * - ADDED: Error percentage report setelah kalibrasi
 * - IMPROVED: Help text dengan kategori yang lebih jelas
 * - FIXED: Leak pada dryerTimer.machineId saat manual stop
 */

#include <WiFi.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>
#include <math.h>
#include <Preferences.h>

// ============== KONFIGURASI SERVER ==============
const char* server_ip = "103.150.226.111";
const char* ssid = "Laundry Coin";
const char* password = "2025*12*20";
const int server_port = 80;
const char* device_id = "esp32_001";
const char* API_PREFIX = "/api/esp32";

// Hardware pins
const int CURRENT_PIN_1 = 34;
const int CURRENT_PIN_2 = 35;
const int RELAY_1 = 25;
const int RELAY_2 = 26;
const int LED_PIN = 2;
const bool RELAY_ACTIVE_HIGH = true;

// Machine ID untuk Unit 1
const int MACHINE_ID_1 = 1;
const int MACHINE_ID_2 = 2;

// Kalibrasi sensor
const float ADC_VOLTAGE_REF = 3.3;
const int ADC_RESOLUTION = 4095;
const float BIAS_VOLTAGE = 1.65;

// SCT-013 10A/1V → 10A menghasilkan 1V RMS
// Factor = 10A / 1V = 10.0
// Jika Anda menggunakan voltage divider atau CT tipe lain,
// factor akan otomatis dikoreksi saat kalibrasi.
const float CT_CALIBRATION_FACTOR = 10.0;

const float CURRENT_THRESHOLD = 0.05;
const int RMS_SAMPLES = 2000;
const int CALIBRATION_SAMPLES = 4000;

// Batas sanity check untuk factor hasil kalibrasi
const float MIN_CAL_FACTOR = 1.0;
const float MAX_CAL_FACTOR = 100.0;

float zeroOffset1 = 0.0;
float zeroOffset2 = 0.0;
float ctFactor1 = CT_CALIBRATION_FACTOR;
float ctFactor2 = CT_CALIBRATION_FACTOR;

Preferences prefs;

unsigned long lastPoll = 0;
unsigned long lastSend = 0;
const unsigned long POLL_INTERVAL = 500;
const unsigned long SEND_INTERVAL = 2000;

bool relay1State = false;
bool relay2State = false;
bool wifiWasConnected = false;
bool sensorsCalibrated = false;

// Current debug values for each CT channel
float currentDebugRmsVoltage[2] = {0.0, 0.0};
float currentDebugRmsCurrent[2] = {0.0, 0.0};
int currentDebugRawLast[2] = {0, 0};
int currentDebugRawMin[2] = {4095, 4095};
int currentDebugRawMax[2] = {0, 0};
float currentDebugRawMean[2] = {0.0, 0.0};
int currentDebugSamples[2] = {0, 0};
unsigned long currentDebugSampleMs[2] = {0, 0};
float currentDebugZeroOffset[2] = {0.0, 0.0};

// TIMER SYSTEM UNTUK DRYER AUTO-STOP
struct DryerTimer {
  bool active;
  unsigned long startMillis;
  int durationMinutes;
  int machineId;
};

DryerTimer dryerTimer = {false, 0, 0, 0};

// MACHINE TYPE CONFIGURATION
const char* MACHINE_TYPE_1 = "washer";
const char* MACHINE_TYPE_2 = "dryer";

// FUNCTION PROTOTYPES
void connectWiFi();
void calibrateSensors();
void recalibrateZeroOffset(int channel);
void testSensors();
float readCurrent(int channel);
void checkDryerTimer();
bool executeCommand(int machineId, const char* command, int durationMinutes);
void sendAck(int commandId, int machineId, bool success);
void sendData();
void pollCommands();
double round2(double value);
void setRelay(int pin, bool on);
bool readRelayNormalized(int pin);
double measureRmsVoltage(int channel, int samplesOverride = 0, int intervalUs = 20);
void autoCalibrateCT(int channel, double knownCurrentA, int repeats = 3, bool save = true);
void autoCalibrateCT_TangAmpere(int channel, double knownCurrentA);
void handleSerialCommands();

// ============== SETUP ==============
void setup() {
  Serial.begin(115200);
  delay(1000);

  Serial.println("\n========================================");
  Serial.println("  ESP32 LAUNDRY MONITOR - UNIT 1 v3.8");
  Serial.println("  Device: esp32_001 | Machines: 1 & 2");
  Serial.println("  Server: 103.150.226.111:3000");
  Serial.println("  ✨ TANG AMPERE CALIBRATION READY");
  Serial.println("========================================");

  analogReadResolution(12);
  analogSetAttenuation(ADC_11db);

  pinMode(RELAY_1, OUTPUT);
  pinMode(RELAY_2, OUTPUT);
  pinMode(LED_PIN, OUTPUT);
  pinMode(CURRENT_PIN_1, INPUT);
  pinMode(CURRENT_PIN_2, INPUT);

  setRelay(RELAY_1, false);
  setRelay(RELAY_2, false);
  digitalWrite(LED_PIN, LOW);

  connectWiFi();
  calibrateSensors();

  // Load persisted CT calibration factors (if any)
  prefs.begin("laundry", false);
  ctFactor1 = prefs.getFloat("ct1", CT_CALIBRATION_FACTOR);
  ctFactor2 = prefs.getFloat("ct2", CT_CALIBRATION_FACTOR);
  prefs.end();

  Serial.print("CT factor CH1: "); Serial.println(ctFactor1, 4);
  Serial.print("CT factor CH2: "); Serial.println(ctFactor2, 4);

  // Check if factors are significantly different
  float factorDiff = fabs(ctFactor1 - ctFactor2);
  float factorAvg = (ctFactor1 + ctFactor2) / 2.0;
  float factorDiffPct = (factorAvg > 0) ? (factorDiff / factorAvg) * 100.0 : 0.0;

  if (factorDiffPct > 10.0) {
    Serial.println("\n⚠️ WARNING: CT factors differ by > 10%!");
    Serial.print("   Difference: "); Serial.print(factorDiffPct, 1); Serial.println("%");
    Serial.println("   Recommend: calibrate both channels with same load");
  }

  // Warning jika factor terlalu jauh dari default (indikasi kalibrasi salah)
  if (ctFactor1 < MIN_CAL_FACTOR || ctFactor1 > MAX_CAL_FACTOR ||
      ctFactor2 < MIN_CAL_FACTOR || ctFactor2 > MAX_CAL_FACTOR) {
    Serial.println("\n🚨 WARNING: Saved calibration factor is outside normal range!");
    Serial.println("   This usually means the previous calibration was done incorrectly.");
    Serial.println("   RECOMMENDATION: Run 'resetcal' then recalibrate properly.");
  }

  testSensors();

  Serial.println("\n========================================");
  Serial.println("Setup complete! Starting main loop...");
  Serial.println("========================================\n");
}

// ============== MAIN LOOP ==============
void loop() {
  if (WiFi.status() == WL_CONNECTED) {
    digitalWrite(LED_PIN, HIGH);

    if (!wifiWasConnected) {
      wifiWasConnected = true;
      Serial.println("[WiFi] Connected! LED ON");
    }
  } else {
    digitalWrite(LED_PIN, LOW);

    if (wifiWasConnected) {
      wifiWasConnected = false;
      Serial.println("[WiFi] Disconnected! LED OFF");
    }

    static unsigned long lastReconnectAttempt = 0;
    if (millis() - lastReconnectAttempt > 5000) {
      lastReconnectAttempt = millis();
      Serial.println("[WiFi] Attempting reconnect...");
      WiFi.reconnect();
    }
    delay(100);
    return;
  }

  unsigned long now = millis();

  checkDryerTimer();

  if (now - lastPoll >= POLL_INTERVAL) {
    lastPoll = now;
    pollCommands();
  }

  if (now - lastSend >= SEND_INTERVAL) {
    lastSend = now;
    sendData();
  }

  handleSerialCommands();

  delay(10);
}

// ============== CHECK DRYER TIMER ==============
void checkDryerTimer() {
  if (!dryerTimer.active) return;

  unsigned long elapsedMillis = millis() - dryerTimer.startMillis;
  unsigned long elapsedMinutes = elapsedMillis / 60000UL;

  static unsigned long lastDebugMinute = 999;
  if (elapsedMinutes != lastDebugMinute) {
    lastDebugMinute = elapsedMinutes;
    Serial.print("[TIMER] Dryer ");
    Serial.print(dryerTimer.machineId);
    Serial.print(" | Elapsed: ");
    Serial.print(elapsedMinutes);
    Serial.print("/");
    Serial.print(dryerTimer.durationMinutes);
    Serial.println(" min");
  }

  if (elapsedMinutes >= (unsigned long)dryerTimer.durationMinutes) {
    Serial.println("\n========================================");
    Serial.print("[TIMER] Dryer ");
    Serial.print(dryerTimer.machineId);
    Serial.println(" TIME'S UP! Auto-stopping...");
    Serial.println("========================================\n");

    int relayPin;
    bool* statePtr;

    if (dryerTimer.machineId == MACHINE_ID_1) {
      relayPin = RELAY_1;
      statePtr = &relay1State;
    } else if (dryerTimer.machineId == MACHINE_ID_2) {
      relayPin = RELAY_2;
      statePtr = &relay2State;
    } else {
      dryerTimer.active = false;
      return;
    }

    setRelay(relayPin, false);
    delay(100);
    *statePtr = readRelayNormalized(relayPin);

    sendData();

    dryerTimer.active = false;
    dryerTimer.machineId = 0;

    Serial.println("[TIMER] Dryer auto-stopped successfully");
  }
}

// ============== WIFI ==============
void connectWiFi() {
  WiFi.mode(WIFI_STA);
  WiFi.begin(ssid, password);

  Serial.print("[WiFi] Connecting to ");
  Serial.print(ssid);

  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 30) {
    delay(500);
    Serial.print(".");
    attempts++;
  }

  if (WiFi.status() == WL_CONNECTED) {
    wifiWasConnected = true;
    digitalWrite(LED_PIN, HIGH);
    Serial.println();
    Serial.print("[WiFi] Connected! IP: ");
    Serial.println(WiFi.localIP());
    Serial.print("[WiFi] SSID: ");
    Serial.println(WiFi.SSID());
    Serial.print("[WiFi] RSSI: ");
    Serial.println(WiFi.RSSI());
  } else {
    wifiWasConnected = false;
    digitalWrite(LED_PIN, LOW);
    Serial.println(" FAILED! Will retry in loop...");
  }
}

// ============== CALIBRATION ==============
void calibrateSensors() {
  Serial.println("Calibrating zero offset (robust two-pass)...");

  const int calSamples = 1000;
  long sum1 = 0, sumSq1 = 0;
  long sum2 = 0, sumSq2 = 0;

  for (int i = 0; i < calSamples; i++) {
    int v1 = analogRead(CURRENT_PIN_1);
    int v2 = analogRead(CURRENT_PIN_2);
    sum1 += v1;
    sumSq1 += (long)v1 * (long)v1;
    sum2 += v2;
    sumSq2 += (long)v2 * (long)v2;
    delayMicroseconds(100);
  }

  float mean1 = sum1 / (float)calSamples;
  float mean2 = sum2 / (float)calSamples;
  float var1 = (sumSq1 / (float)calSamples) - (mean1 * mean1);
  float var2 = (sumSq2 / (float)calSamples) - (mean2 * mean2);
  float std1 = var1 > 0 ? sqrt(var1) : 0.0;
  float std2 = var2 > 0 ? sqrt(var2) : 0.0;

  long trimSum1 = 0, trimSum2 = 0;
  int trimCount1 = 0, trimCount2 = 0;
  for (int i = 0; i < calSamples; i++) {
    int v1 = analogRead(CURRENT_PIN_1);
    int v2 = analogRead(CURRENT_PIN_2);
    if (std1 <= 0 || fabs(v1 - mean1) <= 3.0 * std1) { trimSum1 += v1; trimCount1++; }
    if (std2 <= 0 || fabs(v2 - mean2) <= 3.0 * std2) { trimSum2 += v2; trimCount2++; }
    delayMicroseconds(100);
  }

  float final1 = (trimCount1 > 0) ? (trimSum1 / (float)trimCount1) : mean1;
  float final2 = (trimCount2 > 0) ? (trimSum2 / (float)trimCount2) : mean2;

  zeroOffset1 = final1;
  zeroOffset2 = final2;

  Serial.print("Zero Offset CH1: "); Serial.println(zeroOffset1, 2);
  Serial.print("Zero Offset CH2: "); Serial.println(zeroOffset2, 2);

  sensorsCalibrated = true;
}

// ============== RECALIBRATE ZERO OFFSET (single channel) ==============
void recalibrateZeroOffset(int channel) {
  Serial.print("Recalibrating zero offset for CH"); Serial.println(channel);

  const int calSamples = 1000;
  int pin = (channel == 1) ? CURRENT_PIN_1 : CURRENT_PIN_2;
  long sum = 0, sumSq = 0;

  for (int i = 0; i < calSamples; i++) {
    int raw = analogRead(pin);
    sum += raw;
    sumSq += (long)raw * (long)raw;
    delayMicroseconds(100);
  }

  float mean = sum / (float)calSamples;
  float var = (sumSq / (float)calSamples) - (mean * mean);
  float std = var > 0 ? sqrt(var) : 0.0;

  long trimSum = 0;
  int trimCount = 0;
  for (int i = 0; i < calSamples; i++) {
    int raw = analogRead(pin);
    if (std <= 0 || fabs(raw - mean) <= 3.0 * std) {
      trimSum += raw;
      trimCount++;
    }
    delayMicroseconds(100);
  }

  float finalOffset = (trimCount > 0) ? (trimSum / (float)trimCount) : mean;

  if (channel == 1) {
    zeroOffset1 = finalOffset;
  } else {
    zeroOffset2 = finalOffset;
  }

  Serial.print("New Zero Offset CH"); Serial.print(channel);
  Serial.print(": "); Serial.println(finalOffset, 2);
}

// ============== TEST ==============
void testSensors() {
  Serial.println("Reading raw ADC values (10 samples):");

  for (int i = 0; i < 10; i++) {
    int raw1 = analogRead(CURRENT_PIN_1);
    int raw2 = analogRead(CURRENT_PIN_2);

    float voltage1 = raw1 * (ADC_VOLTAGE_REF / ADC_RESOLUTION);
    float voltage2 = raw2 * (ADC_VOLTAGE_REF / ADC_RESOLUTION);

    Serial.print("  Sample "); Serial.print(i);
    Serial.print(" | CH1 Raw: "); Serial.print(raw1);
    Serial.print(" ("); Serial.print(voltage1, 3); Serial.print("V)");
    Serial.print(" | CH2 Raw: "); Serial.print(raw2);
    Serial.print(" ("); Serial.print(voltage2, 3); Serial.println("V)");

    delay(100);
  }

  Serial.println("\n--- TEST: Relay ON for 3 seconds ---");
  setRelay(RELAY_1, true);
  setRelay(RELAY_2, true);
  relay1State = readRelayNormalized(RELAY_1);
  relay2State = readRelayNormalized(RELAY_2);
  delay(3000);

  Serial.println("Reading with relay ON:");
  for (int i = 0; i < 10; i++) {
    float c1 = readCurrent(1);
    float c2 = readCurrent(2);
    Serial.print("  ON Sample "); Serial.print(i);
    Serial.print(" | CH1: "); Serial.print(c1, 3); Serial.print("A");
    Serial.print(" | CH2: "); Serial.print(c2, 3); Serial.println("A");
    delay(500);
  }

  setRelay(RELAY_1, false);
  setRelay(RELAY_2, false);
  relay1State = readRelayNormalized(RELAY_1);
  relay2State = readRelayNormalized(RELAY_2);
  Serial.println("--- Relay OFF ---\n");
}

// ============== READ CURRENT ==============
float readCurrent(int channel) {
  int idx = channel - 1;
  int pin = (channel == 1) ? CURRENT_PIN_1 : CURRENT_PIN_2;
  float zeroOffset = (channel == 1) ? zeroOffset1 : zeroOffset2;

  double sumSquared = 0;
  long sumRaw = 0;
  int rawMin = ADC_RESOLUTION;
  int rawMax = 0;
  int rawLast = 0;
  int samples = RMS_SAMPLES;
  int sampleInterval = 20;

  unsigned long startTime = micros();

  for (int i = 0; i < samples; i++) {
    int raw = analogRead(pin);
    rawLast = raw;
    if (raw < rawMin) rawMin = raw;
    if (raw > rawMax) rawMax = raw;
    sumRaw += raw;

    double voltage = (raw - zeroOffset) * (ADC_VOLTAGE_REF / ADC_RESOLUTION);
    sumSquared += voltage * voltage;
    delayMicroseconds(sampleInterval);
  }

  unsigned long duration = micros() - startTime;
  if (samples <= 0) return 0.0;
  double meanSquared = sumSquared / (double)samples;
  double rmsVoltage = sqrt(meanSquared);
  double current = rmsVoltage * (channel == 1 ? ctFactor1 : ctFactor2);

  if (current < CURRENT_THRESHOLD) {
    current = 0.0;
  }

  currentDebugRmsVoltage[idx] = rmsVoltage;
  currentDebugRmsCurrent[idx] = (float)current;
  currentDebugRawLast[idx] = rawLast;
  currentDebugRawMin[idx] = rawMin;
  currentDebugRawMax[idx] = rawMax;
  currentDebugRawMean[idx] = sumRaw / (float)samples;
  currentDebugSamples[idx] = samples;
  currentDebugSampleMs[idx] = duration / 1000;
  currentDebugZeroOffset[idx] = zeroOffset;

  // FIXED: static variable dipisah per channel menggunakan array
  static unsigned long lastDebug[2] = {0, 0};
  if (millis() - lastDebug[idx] > 5000) {
    lastDebug[idx] = millis();
    Serial.print("[DEBUG] CH"); Serial.print(channel);
    Serial.print(" | RawLast: "); Serial.print(rawLast);
    Serial.print(" | Min/Max: "); Serial.print(rawMin);
    Serial.print("/"); Serial.print(rawMax);
    Serial.print(" | Mean: "); Serial.print(currentDebugRawMean[idx], 1);
    Serial.print(" | Offset: "); Serial.print(zeroOffset, 1);
    Serial.print(" | RMS_V: "); Serial.print(rmsVoltage, 4);
    Serial.print("V | Current: "); Serial.print(current, 3);
    Serial.print("A | Samples: "); Serial.print(samples);
    Serial.print(" | Time: "); Serial.print(duration / 1000.0, 1);
    Serial.println("ms");
  }

  return (float)current;
}

// ============== EXECUTE COMMAND ==============
bool executeCommand(int machineId, const char* command, int durationMinutes) {
  if (strcmp(command, "START") != 0 && strcmp(command, "STOP") != 0 && strcmp(command, "CALIBRATE") != 0) {
    Serial.print("[CMD] Unknown command: ");
    Serial.println(command);
    return false;
  }

  // Handle CALIBRATE separately
  if (strcmp(command, "CALIBRATE") == 0) {
    // durationMinutes is reused to pass the known current multiplied by 100
    // Example: 5.4A -> durationMinutes = 540
    double knownCurrentA = durationMinutes / 100.0;
    Serial.print("[CMD] Calibration triggered for Machine "); Serial.print(machineId);
    Serial.print(" with known current: "); Serial.println(knownCurrentA);
    
    int channel = (machineId == MACHINE_ID_1) ? 1 : 2;
    autoCalibrateCT_TangAmpere(channel, knownCurrentA);
    return true;
  }

  bool targetState = (strcmp(command, "START") == 0);

  int relayPin;
  bool* statePtr;
  const char* machineType;

  if (machineId == MACHINE_ID_1) {
    relayPin = RELAY_1;
    statePtr = &relay1State;
    machineType = MACHINE_TYPE_1;
  } else if (machineId == MACHINE_ID_2) {
    relayPin = RELAY_2;
    statePtr = &relay2State;
    machineType = MACHINE_TYPE_2;
  } else {
    Serial.print("[CMD] Unknown machine ID: ");
    Serial.println(machineId);
    return false;
  }

  Serial.print("[RELAY] Machine "); Serial.print(machineId);
  Serial.print(" ("); Serial.print(machineType);
  Serial.print(") -> "); Serial.println(targetState ? "ON" : "OFF");

  if (targetState && strcmp(machineType, "dryer") == 0) {
    int duration = durationMinutes > 0 ? durationMinutes : 40;

    dryerTimer.active = true;
    dryerTimer.startMillis = millis();
    dryerTimer.durationMinutes = duration;
    dryerTimer.machineId = machineId;

    Serial.println("\n========================================");
    Serial.print("[TIMER] Dryer timer STARTED: ");
    Serial.print(duration);
    Serial.println(" minutes");
    Serial.println("========================================\n");
  }

  if (!targetState && dryerTimer.machineId == machineId) {
    dryerTimer.active = false;
    dryerTimer.machineId = 0;
    Serial.println("[TIMER] Dryer timer CANCELLED (manual stop)");
  }

  setRelay(relayPin, targetState);
  delay(100);

  bool actualState = readRelayNormalized(relayPin);
  *statePtr = actualState;

  if (actualState != targetState) {
    Serial.print("[RELAY] WARNING: State mismatch! relayPin="); Serial.print(relayPin);
    Serial.print(" read="); Serial.print(digitalRead(relayPin));
    Serial.print(" expectedLevel="); Serial.println(targetState ? (RELAY_ACTIVE_HIGH ? HIGH : LOW) : (RELAY_ACTIVE_HIGH ? LOW : HIGH));
    return false;
  }

  return true;
}

// ============== SEND ACK ==============
void sendAck(int commandId, int machineId, bool success) {
  HTTPClient http;

  String url = String("http://") + server_ip + ":" + server_port + 
               API_PREFIX + "/command/ack";

  http.begin(url);
  http.addHeader("Content-Type", "application/json");
  http.setTimeout(1000);

  StaticJsonDocument<256> doc;
  doc["command_id"] = commandId;
  doc["machine_id"] = machineId;
  doc["success"] = success;

  String payload;
  serializeJson(doc, payload);

  int httpCode = http.POST(payload);

  if (httpCode != 200) {
    Serial.print("[ACK] Failed, HTTP: ");
    Serial.println(httpCode);
  }

  http.end();
}

// ============== POLL COMMANDS ==============
void pollCommands() {
  HTTPClient http;

  String url = String("http://") + server_ip + ":" + server_port + 
               API_PREFIX + "/commands?device_id=" + device_id;

  Serial.print("[CMD] URL: ");
  Serial.println(url);

  http.begin(url);
  http.setTimeout(1000);

  int httpCode = http.GET();

  if (httpCode == 200) {
    String response = http.getString();
    Serial.print("[CMD] Response: "); Serial.println(response);

    StaticJsonDocument<4096> doc;
    DeserializationError error = deserializeJson(doc, response);

    if (!error) {
      JsonArray commands = doc["commands"];

      for (JsonObject cmd : commands) {
        int commandId = cmd["command_id"] | 0;
        int machineId = cmd["machine_id"] | 0;
        const char* commandRaw = cmd["command"] | "";

        int durationMinutes = cmd["duration_minutes"] | 0;
        int sessionId = cmd["session_id"] | 0;
        bool requireSession = false;
        if (cmd.containsKey("require_session")) {
          requireSession = (bool)cmd["require_session"];
        }

        if (commandId == 0 || machineId == 0) continue;

        char commandBuf[32];
        strncpy(commandBuf, commandRaw, sizeof(commandBuf)-1);
        commandBuf[sizeof(commandBuf)-1] = '\0';
        for (char* p = commandBuf; *p; ++p) *p = toupper(*p);

        Serial.print("[CMD] Machine "); Serial.print(machineId);
        Serial.print(" -> "); Serial.print(commandBuf);

        if (durationMinutes > 0) {
          Serial.print(" | Duration: ");
          Serial.print(durationMinutes);
          Serial.print(" min");
        }
        Serial.println();

        if (strcmp(commandBuf, "START") == 0 && requireSession && sessionId == 0) {
          Serial.print("[CMD] Skipping START for machine "); Serial.print(machineId);
          Serial.println(" — no session_id provided");
          continue;
        }

        bool success = executeCommand(machineId, commandBuf, durationMinutes);
        sendAck(commandId, machineId, success);
      }
    } else {
      Serial.print("[CMD] JSON parse error: ");
      Serial.println(error.c_str());
    }
  } else if (httpCode > 0) {
    Serial.print("[CMD] HTTP error: ");
    Serial.println(httpCode);
  } else {
    Serial.print("[CMD] Connection failed: ");
    Serial.println(http.errorToString(httpCode));
  }

  http.end();
}

// ============== SEND DATA ==============
void sendData() {
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("[DATA] WiFi not connected, skip sending");
    return;
  }

  HTTPClient http;

  String url = String("http://") + server_ip + ":" + server_port + 
               API_PREFIX + "/data";

  Serial.print("[DATA] URL: ");
  Serial.println(url);

  http.begin(url);
  http.addHeader("Content-Type", "application/json");
  http.setTimeout(3000);

  relay1State = readRelayNormalized(RELAY_1);
  relay2State = readRelayNormalized(RELAY_2);

  float current1 = readCurrent(1);
  delay(50);
  float current2 = readCurrent(2);

  Serial.print("[DATA] CH1: "); Serial.print(current1, 2);
  Serial.print("A | CH2: "); Serial.print(current2, 2);
  Serial.println("A");

  int remaining1 = 0;
  int remaining2 = 0;

  if (dryerTimer.active) {
    unsigned long elapsed = (millis() - dryerTimer.startMillis) / 60000UL;
    int rem = dryerTimer.durationMinutes - elapsed;
    if (rem < 0) rem = 0;
    
    if (dryerTimer.machineId == MACHINE_ID_1) remaining1 = rem;
    if (dryerTimer.machineId == MACHINE_ID_2) remaining2 = rem;

    Serial.print("[TIMER] Dryer "); Serial.print(dryerTimer.machineId);
    Serial.print(" | "); Serial.print(elapsed);
    Serial.print("/"); Serial.print(dryerTimer.durationMinutes);
    Serial.println(" min remaining");
  }

  StaticJsonDocument<2048> doc;
  doc["device_id"] = device_id;
  doc["wifi_ssid"] = WiFi.SSID();
  doc["wifi_rssi"] = WiFi.RSSI();

  JsonObject ch1 = doc.createNestedObject("channel1");
  ch1["machine_id"] = MACHINE_ID_1;
  ch1["machine_type"] = MACHINE_TYPE_1;
  ch1["current"] = round2(current1);
  ch1["voltage"] = 220.0;
  ch1["relay_status"] = relay1State ? "ON" : "OFF";
  ch1["raw_adc"] = currentDebugRawLast[0];
  ch1["raw_adc_min"] = currentDebugRawMin[0];
  ch1["raw_adc_max"] = currentDebugRawMax[0];
  ch1["raw_adc_mean"] = round2(currentDebugRawMean[0]);
  ch1["zero_offset"] = round2(currentDebugZeroOffset[0]);
  ch1["rms_voltage"] = round2(currentDebugRmsVoltage[0]);
  ch1["samples"] = currentDebugSamples[0];
  ch1["sample_time_ms"] = currentDebugSampleMs[0];
  ch1["threshold"] = CURRENT_THRESHOLD;
  ch1["calibration_factor"] = ctFactor1;
  ch1["dryer_remaining_minutes"] = remaining1;

  JsonObject ch2 = doc.createNestedObject("channel2");
  ch2["machine_id"] = MACHINE_ID_2;
  ch2["machine_type"] = MACHINE_TYPE_2;
  ch2["current"] = round2(current2);
  ch2["voltage"] = 220.0;
  ch2["relay_status"] = relay2State ? "ON" : "OFF";
  ch2["raw_adc"] = currentDebugRawLast[1];
  ch2["raw_adc_min"] = currentDebugRawMin[1];
  ch2["raw_adc_max"] = currentDebugRawMax[1];
  ch2["raw_adc_mean"] = round2(currentDebugRawMean[1]);
  ch2["zero_offset"] = round2(currentDebugZeroOffset[1]);
  ch2["rms_voltage"] = round2(currentDebugRmsVoltage[1]);
  ch2["samples"] = currentDebugSamples[1];
  ch2["sample_time_ms"] = currentDebugSampleMs[1];
  ch2["threshold"] = CURRENT_THRESHOLD;
  ch2["calibration_factor"] = ctFactor2;
  ch2["dryer_remaining_minutes"] = remaining2;

  String payload;
  serializeJson(doc, payload);

  Serial.print("[DATA] Payload: ");
  Serial.println(payload);

  int httpCode = http.POST(payload);

  if (httpCode == 200) {
    String response = http.getString();
    Serial.println("[DATA] Sent OK");
  } else {
    Serial.print("[DATA] Failed, HTTP code: ");
    Serial.println(httpCode);
    if (httpCode == -1) {
      Serial.println("[DATA] Error: Connection refused or timeout");
    }
  }

  http.end();
}

// ============== HELPER ==============
double round2(double value) {
  if (value < 0) return 0;
  return (int)(value * 100 + 0.5) / 100.0;
}

// ===== Relay helpers (respect relay active polarity) =====
void setRelay(int pin, bool on) {
  int level = on ? (RELAY_ACTIVE_HIGH ? HIGH : LOW) : (RELAY_ACTIVE_HIGH ? LOW : HIGH);
  digitalWrite(pin, level);
}

bool readRelayNormalized(int pin) {
  return digitalRead(pin) == (RELAY_ACTIVE_HIGH ? HIGH : LOW);
}

// ==================== AUTOCALIBRATE CT (ORIGINAL) ====================
double measureRmsVoltage(int channel, int samplesOverride, int intervalUs) {
  const int samples = (samplesOverride > 0) ? samplesOverride : RMS_SAMPLES;
  double sumSquared = 0.0;
  for (int i = 0; i < samples; i++) {
    int raw = analogRead(channel == 1 ? CURRENT_PIN_1 : CURRENT_PIN_2);
    double v = (raw - (channel == 1 ? zeroOffset1 : zeroOffset2)) * (ADC_VOLTAGE_REF / (double)ADC_RESOLUTION);
    sumSquared += v * v;
    delayMicroseconds(intervalUs);
  }
  double meanSq = sumSquared / (double)samples;
  return sqrt(meanSq);
}

void autoCalibrateCT(int channel, double knownCurrentA, int repeats, bool save) {
  if (knownCurrentA <= 0) {
    Serial.println("❌ Error: Known current must be > 0");
    return;
  }

  Serial.print("Auto-calibrating CT channel "); Serial.print(channel);
  Serial.print(" with known current "); Serial.print(knownCurrentA); Serial.println(" A");

  if (save) {
    Serial.println("  ⚠️  Make sure the machine is RUNNING with STABLE current!");
    Serial.println("  ⚠️  Verify actual current with clamp meter before proceeding!");
  } else {
    Serial.println("  [TEST MODE - will NOT save]");
  }

  // CRITICAL FIX: Recalibrate zero offset sebelum mengukur arus
  Serial.println("  → Recalibrating zero offset first...");
  recalibrateZeroOffset(channel);
  delay(200);

  double accumVrms = 0.0;
  double minVrms = 999.0;
  double maxVrms = 0.0;

  for (int r = 0; r < repeats; r++) {
    double vrms = measureRmsVoltage(channel, CALIBRATION_SAMPLES, 20);
    Serial.print("  Measure "); Serial.print(r+1); Serial.print("/"); Serial.print(repeats);
    Serial.print(": Vrms="); Serial.println(vrms, 6);

    if (vrms < 0.001) {
      Serial.println("  ⚠️ WARNING: Vrms too low! Check if machine is running.");
    }

    accumVrms += vrms;
    if (vrms < minVrms) minVrms = vrms;
    if (vrms > maxVrms) maxVrms = vrms;
    delay(300);
  }

  double avgVrms = accumVrms / (double)repeats;
  double vrmsVariation = (avgVrms > 0.001) ? ((maxVrms - minVrms) / avgVrms * 100.0) : 0.0;

  Serial.print("  Average Vrms: "); Serial.println(avgVrms, 6);
  Serial.print("  Variation: "); Serial.print(vrmsVariation, 2); Serial.println("%");

  if (vrmsVariation > 20.0) {
    Serial.println("  ⚠️ WARNING: High variation between measurements! Current may be unstable.");
  }

  if (avgVrms <= 0.005) {
    Serial.println("❌ Calibration FAILED: measured Vrms is too low (");
    Serial.print(avgVrms, 6); Serial.println("V)");
    Serial.println("   Make sure machine is running and drawing current!");
    return;
  }

  double newFactor = (double)knownCurrentA / avgVrms;

  Serial.print("  Calculated factor: "); Serial.println(newFactor, 6);

  if (newFactor < MIN_CAL_FACTOR || newFactor > MAX_CAL_FACTOR) {
    Serial.println("🚨 Calibration REJECTED: factor outside safe range!");
    Serial.print("   Allowed range: "); Serial.print(MIN_CAL_FACTOR);
    Serial.print(" - "); Serial.print(MAX_CAL_FACTOR); Serial.println(" A/V");
    Serial.println("   Common causes:");
    Serial.println("   1. Wrong 'known current' entered (most likely)");
    Serial.println("   2. Different CT type than SCT-013 10A/1V");
    Serial.println("   3. Voltage divider on signal not accounted for");
    Serial.println("   4. Machine not running during calibration");
    return;
  }

  if (!save) {
    Serial.println("  [TEST MODE] Factor NOT saved. Use 'cal1/cal2' to save permanently.");
    return;
  }

  prefs.begin("laundry", false);
  if (channel == 1) {
    ctFactor1 = (float)newFactor;
    prefs.putFloat("ct1", ctFactor1);
  } else {
    ctFactor2 = (float)newFactor;
    prefs.putFloat("ct2", ctFactor2);
  }
  prefs.end();

  Serial.print("✅ New CT factor for CH"); Serial.print(channel); 
  Serial.print(" SAVED: "); Serial.println(newFactor, 6);

  float factorDiff = fabs(ctFactor1 - ctFactor2);
  float factorAvg = (ctFactor1 + ctFactor2) / 2.0;
  if (factorAvg > 0) {
    float factorDiffPct = (factorDiff / factorAvg) * 100.0;
    Serial.print("   Factor difference CH1 vs CH2: "); 
    Serial.print(factorDiffPct, 2); Serial.println("%");
    if (factorDiffPct > 10.0) {
      Serial.println("   ⚠️ WARNING: Factors differ by > 10%! Calibrate both with same load.");
    }
  }
}

// ==================== AUTOCALIBRATE CT TANG AMPERE v3.8 ====================
void autoCalibrateCT_TangAmpere(int channel, double knownCurrentA) {
  if (knownCurrentA <= 0.3) {
    Serial.println("❌ Error: Arus tang ampere harus > 0.3A");
    return;
  }

  Serial.print("\n🔧 KALIBRASI TANG AMPERE - CH"); Serial.println(channel);
  Serial.print("   Arus referensi (tang ampere): "); Serial.print(knownCurrentA); Serial.println(" A");
  Serial.println("   Pastikan mesin running STABIL selama 5 detik...");

  // Recalibrate zero offset dulu (kritis!)
  Serial.println("   → Recalibrating zero offset...");
  recalibrateZeroOffset(channel);
  delay(500);

  // Ambil 5x pengukuran Vrms (lebih banyak untuk akurasi)
  double accumVrms = 0.0;
  double minVrms = 999.0;
  double maxVrms = 0.0;
  const int repeats = 5;

  for (int r = 0; r < repeats; r++) {
    double vrms = measureRmsVoltage(channel, CALIBRATION_SAMPLES, 20);
    Serial.print("   Sample "); Serial.print(r+1); Serial.print("/"); Serial.print(repeats);
    Serial.print(": Vrms="); Serial.print(vrms, 6); Serial.println("V");

    accumVrms += vrms;
    if (vrms < minVrms) minVrms = vrms;
    if (vrms > maxVrms) maxVrms = vrms;
    delay(500);
  }

  double avgVrms = accumVrms / (double)repeats;
  double vrmsVariation = (avgVrms > 0.001) ? ((maxVrms - minVrms) / avgVrms * 100.0) : 0.0;

  Serial.print("\n   Rata-rata Vrms: "); Serial.print(avgVrms, 6); Serial.println("V");
  Serial.print("   Variasi: "); Serial.print(vrmsVariation, 2); Serial.println("%");

  // Validasi
  if (avgVrms <= 0.005) {
    Serial.println("❌ Kalibrasi GAGAL: Vrms terlalu rendah!");
    Serial.println("   Cek: mesin running? CT terpasang? Kabel tidak putus?");
    return;
  }

  if (vrmsVariation > 15.0) {
    Serial.println("⚠️  WARNING: Arus tidak stabil! Variasi > 15%");
    Serial.println("   Saran: tunggu mesin steady state, ulangi kalibrasi");
  }

  // Hitung factor baru
  double newFactor = (double)knownCurrentA / avgVrms;

  Serial.print("\n   Perhitungan: "); Serial.print(knownCurrentA);
  Serial.print("A / "); Serial.print(avgVrms, 6);
  Serial.print("V = "); Serial.print(newFactor, 4); Serial.println(" A/V");

  // Sanity check
  if (newFactor < MIN_CAL_FACTOR || newFactor > MAX_CAL_FACTOR) {
    Serial.println("🚨 Factor DITOLAK: di luar range aman!");
    Serial.print("   Range: "); Serial.print(MIN_CAL_FACTOR);
    Serial.print(" - "); Serial.print(MAX_CAL_FACTOR); Serial.println(" A/V");
    Serial.println("   Kemungkinan: CT salah tipe, atau arus tang ampere salah input");
    return;
  }

  // Simpan ke flash
  prefs.begin("laundry", false);
  if (channel == 1) {
    ctFactor1 = (float)newFactor;
    prefs.putFloat("ct1", ctFactor1);
  } else {
    ctFactor2 = (float)newFactor;
    prefs.putFloat("ct2", ctFactor2);
  }
  prefs.end();

  // Verifikasi: baca ulang arus dengan factor baru
  Serial.println("\n   ✅ Factor TERSIMPAN!");
  delay(200);
  recalibrateZeroOffset(channel);
  delay(100);
  double verifyVrms = measureRmsVoltage(channel, RMS_SAMPLES, 20);
  double verifyCurrent = verifyVrms * newFactor;

  Serial.print("   Verifikasi: Vrms="); Serial.print(verifyVrms, 4);
  Serial.print("V → Arus="); Serial.print(verifyCurrent, 2);
  Serial.print("A (target: "); Serial.print(knownCurrentA); Serial.println("A)");

  double error = fabs(verifyCurrent - knownCurrentA) / knownCurrentA * 100.0;
  Serial.print("   Error: "); Serial.print(error, 1); Serial.println("%");

  if (error > 10.0) {
    Serial.println("   ⚠️  Error > 10%! Cek ulang tang ampere atau CT");
  } else {
    Serial.println("   ✓ Kalibrasi BERHASIL!");
  }
}

// ==================== SERIAL COMMANDS v3.8 ====================
void handleSerialCommands() {
  if (!Serial || !Serial.available()) return;
  String line = Serial.readStringUntil('\n');
  line.trim();
  if (line.length() == 0) return;

  if (line.startsWith("tanga1 ")) {
    double val = line.substring(7).toFloat();
    if (val > 0) autoCalibrateCT_TangAmpere(1, val);
  } else if (line.startsWith("tanga2 ")) {
    double val = line.substring(7).toFloat();
    if (val > 0) autoCalibrateCT_TangAmpere(2, val);
  } else if (line.startsWith("qcal ")) {
    String args = line.substring(5);
    int spaceIdx = args.indexOf(' ');
    if (spaceIdx > 0) {
      double arus1 = args.substring(0, spaceIdx).toFloat();
      double arus2 = args.substring(spaceIdx + 1).toFloat();
      if (arus1 > 0 && arus2 > 0) {
        autoCalibrateCT_TangAmpere(1, arus1);
        delay(500);
        autoCalibrateCT_TangAmpere(2, arus2);
      } else {
        Serial.println("❌ Format: qcal <arus1> <arus2>");
      }
    } else {
      Serial.println("❌ Format: qcal <arus1> <arus2>");
    }
  } else if (line.startsWith("err1 ")) {
    double tangAmpere = line.substring(5).toFloat();
    if (tangAmpere > 0) {
      recalibrateZeroOffset(1);
      delay(100);
      double vrms = measureRmsVoltage(1, RMS_SAMPLES, 20);
      double current = vrms * ctFactor1;
      double error = (current - tangAmpere) / tangAmpere * 100.0;
      Serial.print("\nCH1: ESP="); Serial.print(current, 2);
      Serial.print("A | Tang="); Serial.print(tangAmpere, 2);
      Serial.print("A | Error="); Serial.print(error, 1); Serial.println("%");
      if (fabs(error) > 10) {
        Serial.println("  ⚠️  Error besar! Gunakan: tanga1 <arus> untuk kalibrasi ulang");
      }
    }
  } else if (line.startsWith("err2 ")) {
    double tangAmpere = line.substring(5).toFloat();
    if (tangAmpere > 0) {
      recalibrateZeroOffset(2);
      delay(100);
      double vrms = measureRmsVoltage(2, RMS_SAMPLES, 20);
      double current = vrms * ctFactor2;
      double error = (current - tangAmpere) / tangAmpere * 100.0;
      Serial.print("\nCH2: ESP="); Serial.print(current, 2);
      Serial.print("A | Tang="); Serial.print(tangAmpere, 2);
      Serial.print("A | Error="); Serial.print(error, 1); Serial.println("%");
      if (fabs(error) > 10) {
        Serial.println("  ⚠️  Error besar! Gunakan: tanga2 <arus> untuk kalibrasi ulang");
      }
    }
  } else if (line.startsWith("cal1 ")) {
    double val = line.substring(5).toFloat();
    if (val > 0) autoCalibrateCT(1, val, 3, true);
  } else if (line.startsWith("cal2 ")) {
    double val = line.substring(5).toFloat();
    if (val > 0) autoCalibrateCT(2, val, 3, true);
  } else if (line.startsWith("calboth ")) {
    double val = line.substring(8).toFloat();
    if (val > 0) {
      autoCalibrateCT(1, val, 3, true);
      delay(200);
      autoCalibrateCT(2, val, 3, true);
    }
  } else if (line.startsWith("testcal1 ")) {
    double val = line.substring(9).toFloat();
    if (val > 0) autoCalibrateCT(1, val, 3, false);
  } else if (line.startsWith("testcal2 ")) {
    double val = line.substring(9).toFloat();
    if (val > 0) autoCalibrateCT(2, val, 3, false);
  } else if (line.startsWith("setfactor1 ")) {
    double val = line.substring(11).toFloat();
    if (val >= MIN_CAL_FACTOR && val <= MAX_CAL_FACTOR) {
      ctFactor1 = val;
      prefs.begin("laundry", false);
      prefs.putFloat("ct1", ctFactor1);
      prefs.end();
      Serial.print("✅ CT factor CH1 manually set to: "); Serial.println(ctFactor1, 4);
    } else {
      Serial.println("❌ Factor outside allowed range");
    }
  } else if (line.startsWith("setfactor2 ")) {
    double val = line.substring(11).toFloat();
    if (val >= MIN_CAL_FACTOR && val <= MAX_CAL_FACTOR) {
      ctFactor2 = val;
      prefs.begin("laundry", false);
      prefs.putFloat("ct2", ctFactor2);
      prefs.end();
      Serial.print("✅ CT factor CH2 manually set to: "); Serial.println(ctFactor2, 4);
    } else {
      Serial.println("❌ Factor outside allowed range");
    }
  } else if (line.startsWith("showraw ")) {
    int ch = line.substring(8).toInt();
    if (ch == 1 || ch == 2) {
      Serial.print("Raw Vrms CH"); Serial.print(ch); Serial.print(": ");
      double vrms = measureRmsVoltage(ch, CALIBRATION_SAMPLES, 20);
      Serial.print(vrms, 6); Serial.println("V");
      Serial.print("Estimated current (default factor 10.0): ");
      Serial.print(vrms * CT_CALIBRATION_FACTOR, 3); Serial.println("A");
      Serial.print("Estimated current (current factor "); 
      Serial.print(ch == 1 ? ctFactor1 : ctFactor2, 2);
      Serial.print("): ");
      Serial.print(vrms * (ch == 1 ? ctFactor1 : ctFactor2), 3); Serial.println("A");
    } else {
      Serial.println("Usage: showraw <1|2>");
    }
  } else if (line == "showcal") {
    Serial.print("CT factor CH1: "); Serial.println(ctFactor1, 6);
    Serial.print("CT factor CH2: "); Serial.println(ctFactor2, 6);
    float factorDiff = fabs(ctFactor1 - ctFactor2);
    float factorAvg = (ctFactor1 + ctFactor2) / 2.0;
    if (factorAvg > 0) {
      float factorDiffPct = (factorDiff / factorAvg) * 100.0;
      Serial.print("Difference: "); Serial.print(factorDiffPct, 2); Serial.println("%");
      if (factorDiffPct > 10.0) {
        Serial.println("⚠️  WARNING: Factors differ by > 10%!");
      }
    }
  } else if (line == "resetcal") {
    Serial.println("Resetting calibration factors to default...");
    prefs.begin("laundry", false);
    prefs.putFloat("ct1", CT_CALIBRATION_FACTOR);
    prefs.putFloat("ct2", CT_CALIBRATION_FACTOR);
    prefs.end();
    ctFactor1 = CT_CALIBRATION_FACTOR;
    ctFactor2 = CT_CALIBRATION_FACTOR;
    Serial.print("✅ Calibration reset to default ("); 
    Serial.print(CT_CALIBRATION_FACTOR, 1); 
    Serial.println(")");
    Serial.println("   Please recalibrate both channels if needed!");
  } else if (line == "recal_zero") {
    recalibrateZeroOffset(1);
    recalibrateZeroOffset(2);
  } else if (line.startsWith("force_start ")) {
    int mid = line.substring(12).toInt();
    if (mid == 1 || mid == 2) {
      Serial.print("Force START machine "); Serial.println(mid);
      bool ok = executeCommand(mid, "START", 0);
      Serial.print("Force START result: "); Serial.println(ok ? "OK" : "FAIL");
    } else {
      Serial.println("Usage: force_start <1|2>");
    }
  } else if (line.startsWith("force_stop ")) {
    int mid = line.substring(11).toInt();
    if (mid == 1 || mid == 2) {
      Serial.print("Force STOP machine "); Serial.println(mid);
      bool ok = executeCommand(mid, "STOP", 0);
      Serial.print("Force STOP result: "); Serial.println(ok ? "OK" : "FAIL");
    } else {
      Serial.println("Usage: force_stop <1|2>");
    }
  } else {
    Serial.print("Unknown command: "); Serial.println(line);
    Serial.println("\n═══════════════════════════════════════════");
    Serial.println("  🔧 KALIBRASI DENGAN TANG AMPERE (v3.8):");
    Serial.println("═══════════════════════════════════════════");
    Serial.println("  tanga1 <A>         - Kalibrasi CH1 dengan arus tang ampere");
    Serial.println("  tanga2 <A>         - Kalibrasi CH2 dengan arus tang ampere");
    Serial.println("  qcal <A1> <A2>     - Kalibrasi cepat kedua channel");
    Serial.println("  err1 <A>           - Cek error CH1 vs tang ampere");
    Serial.println("  err2 <A>           - Cek error CH2 vs tang ampere");
    Serial.println("\n  KALIBRASI BIASA:");
    Serial.println("  cal1 <A>           - Calibrate CH1 (SAVE)");
    Serial.println("  cal2 <A>           - Calibrate CH2 (SAVE)");
    Serial.println("  calboth <A>        - Calibrate both channels");
    Serial.println("  testcal1 <A>       - Test CH1 (NO SAVE)");
    Serial.println("  testcal2 <A>       - Test CH2 (NO SAVE)");
    Serial.println("  setfactor1 <val>   - Set CH1 manual");
    Serial.println("  setfactor2 <val>   - Set CH2 manual");
    Serial.println("  showraw <1|2>      - Show Vrms & estimated A");
    Serial.println("  showcal            - Show current factors");
    Serial.println("  resetcal           - Reset to default (10.0)");
    Serial.println("  recal_zero         - Recalibrate zero offsets");
    Serial.println("\n  KONTROL:");
    Serial.println("  force_start <1|2>  - Force start machine");
    Serial.println("  force_stop <1|2>   - Force stop machine");
    Serial.println("═══════════════════════════════════════════");
  }
}