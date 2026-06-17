const fs = require('fs');
function fixConst(filePath) {
    let content = fs.readFileSync(filePath, 'utf8');
    content = content.replace(/const\s+Text\s*\(\s*AppLocalizations/g, 'Text(AppLocalizations');
    content = content.replace(/const\s+Text\s*\(\s*"👋 "\s*\+\s*greeting/g, 'Text("👋 " + greeting');
    content = content.replace(/const\s+Tab\s*\(\s*text:\s*AppLocalizations/g, 'Tab(text: AppLocalizations');
    content = content.replace(/const\s+Center\s*\(\s*child:\s*Text\s*\(\s*AppLocalizations/g, 'Center(child: Text(AppLocalizations');
    // We should also replace the `const SizedBox` and other parents if they contain AppLocalizations, but standard regex handles the immediate `const Text`.
    fs.writeFileSync(filePath, content);
}
fixConst('lib/home_tab.dart');
fixConst('lib/dashboard.dart');
console.log('Fixed constants');
