const fs = require('fs');

function fix(filePath) {
    let content = fs.readFileSync(filePath, 'utf8');
    content = content.replace(/const\s+Row\s*\(\s*children:\s*\[\s*Icon\(Icons\.star/g, 'Row(children: [Icon(Icons.star');
    content = content.replace(/const\s+Padding\s*\(\s*padding:\s*EdgeInsets\.only\(bottom:\s*8\.0\),\s*child:\s*Text\(AppLocalizations/g, 'Padding(padding: EdgeInsets.only(bottom: 8.0), child: Text(AppLocalizations');
    content = content.replace(/final String title;/, 'final String? title;');
    content = content.replace(/Text\(widget\.title, style: const TextStyle\(color: Colors\.white, fontSize: 16\)\),/, "Text(widget.title ?? AppLocalizations.tr('token_balance'), style: const TextStyle(color: Colors.white, fontSize: 16)),");
    fs.writeFileSync(filePath, content);
}

fix('lib/home_tab.dart');
fix('lib/dashboard.dart');
console.log('Fixed');
