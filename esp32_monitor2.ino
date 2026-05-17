/*
 * ESP32 LAUNDRY MONITOR - UNIT 2 (Mesin 3 & 4)
 * Server: 103.150.226.111:80
 * Device: esp32_002
 */

#include <WiFi.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>

// ============== KONFIGURASI SERVER ==============
const char* server_ip = "103.150.226.111";
const char* ssid = "Laundry Coin";
const char* password = "2025*12*20";
const int server_port = 80;
const char* device_id = "esp32_002";
const char* API_PREFIX = "/api/esp32";

// Hardware pins — BERBEDA dengan Unit 1
const int CURRENT_PIN_1 = 34;
const int CURRENT_PIN_2 = 35;
const int RELAY_1 = 25;   // GPIO 25 (berbeda Unit 1)
const int RELAY_2 = 26;   // GPIO 26 (berbeda Unit 1)
const int LED_PIN = 2;

// Machine ID untuk Unit 2
const int MACHINE_ID_1 = 3;  // Washer 2
const int MACHINE_ID_2 = 4;  // Dryer 2

// Kalibrasi sensor
const float ADC_VOLTAGE_REF = 3.3;
const int ADC_RESOLUTION = 4095;
const float CT_CALIBRATION_FACTOR = 30.0;
const float CURRENT_THRESHOLD = 0.05;
const int RMS_SAMPLES = 2000;

float zeroOffset1 = 0.0;
float zeroOffset2 = 0.0;

unsigned long lastPoll = 0;
unsigned long lastSend = 0;
const unsigned long POLL_INTERVAL = 500;
const unsigned long SEND_INTERVAL = 2000;

bool relay1State = false;
bool relay2State = false;
bool wifiWasConnected = false;

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
  Serial.println("Calibrating zero offset...");
  long sum1 = 0, sum2 = 0;
  int calSamples = 1000;
  for (int i = 0; i < calSamples; i++) {
    sum1 += analogRead(CURRENT_PIN_1);
    sum2 += analogRead(CURRENT_PIN_2);
    delayMicroseconds(100);
  }
  zeroOffset1 = sum1 / (float)calSamples;
  zeroOffset2 = sum2 / (float)calSamples;
  Serial.print("Zero Offset CH1: ");
  Serial.println(zeroOffset1);
  Serial.print("Zero Offset CH2: ");
  Serial.println(zeroOffset2);
}

// ============== READ CURRENT ==============
float readCurrent(int channel) {
  int pin = (channel == 1) ? CURRENT_PIN_1 : CURRENT_PIN_2;
  float zeroOffset = (channel == 1) ? zeroOffset1 : zeroOffset2;
  double sumSquared = 0;
  int samples = RMS_SAMPLES;
  int sampleInterval = 20;
  unsigned long startTime = micros();
  for (int i = 0; i < samples; i++) {
    int raw = analogRead(pin);
    double voltage = (raw - zeroOffset) * (ADC_VOLTAGE_REF / ADC_RESOLUTION);
    sumSquared += voltage * voltage;
    delayMicroseconds(sampleInterval);
  }
  unsigned long duration = micros() - startTime;
  double meanSquared = sumSquared / samples;
  double rmsVoltage = sqrt(meanSquared);
  double current = rmsVoltage * CT_CALIBRATION_FACTOR;
  if (current < CURRENT_THRESHOLD) {
    current = 0.0;
  }
  static unsigned long lastDebug = 0;
  if (millis() - lastDebug > 5000) {
    lastDebug = millis();
    Serial.print("[DEBUG] CH");
    Serial.print(channel);
    Serial.print(" | RMS_V: ");
    Serial.print(rmsVoltage, 4);
    Serial.print("V | Current: ");
    Serial.print(current, 3);
    Serial.print("A | Samples: ");
    Serial.print(samples);
    Serial.print(" | Time: ");
    Serial.print(duration / 1000.0, 1);
    Serial.println("ms");
  }
  return (float)current;
}

// ============== EXECUTE COMMAND ==============
bool executeCommand(int machineId, const char* command, int durationMinutes = 0) {
  if (strcmp(command, "START") != 0 && strcmp(command, "STOP") != 0) {
    Serial.print("[CMD] Unknown command: ");
    Serial.println(command);
    return false;
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
  Serial.print("[RELAY] Machine ");
  Serial.print(machineId);
  Serial.print(" (");
  Serial.print(machineType);
  Serial.print(") -> ");
  Serial.println(targetState ? "ON" : "OFF");
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
  digitalWrite(relayPin, targetState ? HIGH : LOW);
  delay(100);
  bool actualState = digitalRead(relayPin) == HIGH;
  *statePtr = actualState;
  if (actualState != targetState) {
    Serial.println("[RELAY] WARNING: State mismatch!");
    return false;
  }
  return true;
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
    digitalWrite(relayPin, LOW);
    delay(100);
    *statePtr = (digitalRead(relayPin) == HIGH);
    sendData();
    dryerTimer.active = false;
    dryerTimer.machineId = 0;
    Serial.println("[TIMER] Dryer auto-stopped successfully");
  }
}

// ============== SEND ACK ==============
void sendAck(int commandId, int machineId, bool success) {
  HTTPClient http;
  String url = String("http://") + server_ip + ":" + server_port + API_PREFIX + "/command/ack";
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
  String url = String("http://") + server_ip + ":" + server_port + API_PREFIX + "/commands?device_id=" + device_id;
  Serial.print("[CMD] URL: ");
  Serial.println(url);
  http.begin(url);
  http.setTimeout(1000);
  int httpCode = http.GET();
  if (httpCode == 200) {
    String response = http.getString();
    StaticJsonDocument<4096> doc;
    DeserializationError error = deserializeJson(doc, response);
    if (!error) {
      JsonArray commands = doc["commands"];
      for (JsonObject cmd : commands) {
        int commandId = cmd["command_id"] | 0;
        int machineId = cmd["machine_id"] | 0;
        const char* command = cmd["command"] | "";
        int durationMinutes = cmd["duration_minutes"] | 0;
        if (commandId == 0 || machineId == 0) continue;
        Serial.print("[CMD] Machine ");
        Serial.print(machineId);
        Serial.print(" -> ");
        Serial.print(command);
        if (durationMinutes > 0) {
          Serial.print(" | Duration: ");
          Serial.print(durationMinutes);
          Serial.print(" min");
        }
        Serial.println();
        bool success = executeCommand(machineId, command, durationMinutes);
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
  String url = String("http://") + server_ip + ":" + server_port + API_PREFIX + "/data";
  Serial.print("[DATA] URL: ");
  Serial.println(url);
  http.begin(url);
  http.addHeader("Content-Type", "application/json");
  http.setTimeout(3000);
  relay1State = digitalRead(RELAY_1) == HIGH;
  relay2State = digitalRead(RELAY_2) == HIGH;
  float current1 = readCurrent(1);
  delay(50);
  float current2 = readCurrent(2);
  Serial.print("[DATA] CH1: ");
  Serial.print(current1, 2);
  Serial.print("A | CH2: ");
  Serial.print(current2, 2);
  Serial.println("A");
  if (dryerTimer.active) {
    unsigned long elapsed = (millis() - dryerTimer.startMillis) / 60000UL;
    Serial.print("[TIMER] Dryer ");
    Serial.print(dryerTimer.machineId);
    Serial.print(" | ");
    Serial.print(elapsed);
    Serial.print("/");
    Serial.print(dryerTimer.durationMinutes);
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
  ch1["raw_adc"] = analogRead(CURRENT_PIN_1);
  JsonObject ch2 = doc.createNestedObject("channel2");
  ch2["machine_id"] = MACHINE_ID_2;
  ch2["machine_type"] = MACHINE_TYPE_2;
  ch2["current"] = round2(current2);
  ch2["voltage"] = 220.0;
  ch2["relay_status"] = relay2State ? "ON" : "OFF";
  ch2["raw_adc"] = analogRead(CURRENT_PIN_2);
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

// ============== SETUP ==============
void setup() {
  Serial.begin(115200);
  delay(1000);
  Serial.println("\n========================================");
  Serial.println("  ESP32 LAUNDRY MONITOR - UNIT 2 v3.4");
  Serial.println("  Device: esp32_002 | Machines: 3 & 4");
  Serial.println("  Server: 103.150.226.111:80");
  Serial.println("========================================");
  analogReadResolution(12);
  analogSetAttenuation(ADC_11db);
  pinMode(RELAY_1, OUTPUT);
  pinMode(RELAY_2, OUTPUT);
  pinMode(LED_PIN, OUTPUT);
  pinMode(CURRENT_PIN_1, INPUT);
  pinMode(CURRENT_PIN_2, INPUT);
  digitalWrite(RELAY_1, LOW);
  digitalWrite(RELAY_2, LOW);
  digitalWrite(LED_PIN, LOW);
  connectWiFi();
  calibrateSensors();
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
  delay(10);
}
