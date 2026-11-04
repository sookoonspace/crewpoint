const _formulaLeads = {'=', '+', '-', '@', '\t', '\r'};

/// Makes a CSV cell safe to open in a spreadsheet, which would otherwise run a
/// cell starting with one of these characters as a formula. A leading apostrophe
/// makes it plain text. Every CSV export should pass every cell through this.
String neutraliseCsvCell(String cell) =>
    cell.isNotEmpty && _formulaLeads.contains(cell[0]) ? "'$cell" : cell;
