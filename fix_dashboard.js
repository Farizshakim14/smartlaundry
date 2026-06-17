const fs = require('fs');
let content = fs.readFileSync('lib/dashboard.dart', 'utf8');
const start = content.indexOf('class LiveMachineItem');
const end = content.indexOf('class AnimatedTokenCard');
if(start > -1 && end > -1) {
  content = content.substring(0, start) + content.substring(end);
}
content = "import 'package:aplikasilaundry/live_machine_item.dart';\n" + content;
fs.writeFileSync('lib/dashboard.dart', content);
console.log('Done');
