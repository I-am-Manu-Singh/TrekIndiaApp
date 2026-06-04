import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';

/// Generates a proper .xlsx file from a list of rows (first row = headers).
/// Uses only the [archive] package (already a transitive dep via lottie).
/// No [excel] package needed — avoids the archive version conflict.
class XlsxService {
  static Uint8List buildXlsx(List<List<dynamic>> rows) {
    // ── Shared Strings ─────────────────────────────────────────────────────
    // Collect all unique string values for the shared strings table
    final strings = <String>[];
    final stringIndex = <String, int>{};

    int _strIdx(String s) {
      if (stringIndex.containsKey(s)) return stringIndex[s]!;
      final idx = strings.length;
      strings.add(s);
      stringIndex[s] = idx;
      return idx;
    }

    // ── Build sheet XML ────────────────────────────────────────────────────
    final sheetBuf = StringBuffer();
    sheetBuf.write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>');
    sheetBuf.write('<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"'
        ' xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">');
    sheetBuf.write('<sheetData>');

    for (int r = 0; r < rows.length; r++) {
      final row = rows[r];
      final rowNum = r + 1;
      sheetBuf.write('<row r="$rowNum">');
      for (int c = 0; c < row.length; c++) {
        final colLetter = _colLetter(c);
        final cellRef = '$colLetter$rowNum';
        final value = row[c];
        if (value == null) {
          sheetBuf.write('<c r="$cellRef"/>');
        } else if (value is num) {
          sheetBuf.write('<c r="$cellRef"><v>$value</v></c>');
        } else {
          // String cell — use shared strings
          final str = value.toString()
              .replaceAll('&', '&amp;')
              .replaceAll('<', '&lt;')
              .replaceAll('>', '&gt;')
              .replaceAll('"', '&quot;')
              .replaceAll("'", '&apos;');
          final idx = _strIdx(str);
          // s="1" = header style (bold), s="0" = normal
          final styleAttr = r == 0 ? ' s="1"' : '';
          sheetBuf.write('<c r="$cellRef" t="s"$styleAttr><v>$idx</v></c>');
        }
      }
      sheetBuf.write('</row>');
    }
    sheetBuf.write('</sheetData>');
    sheetBuf.write('</worksheet>');

    // ── Shared Strings XML ─────────────────────────────────────────────────
    final ssBuf = StringBuffer();
    ssBuf.write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>');
    ssBuf.write('<sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"'
        ' count="${strings.length}" uniqueCount="${strings.length}">');
    for (final s in strings) {
      ssBuf.write('<si><t xml:space="preserve">$s</t></si>');
    }
    ssBuf.write('</sst>');

    // ── Styles XML (bold for header row) ──────────────────────────────────
    const stylesXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
  <fonts>
    <font><sz val="11"/><name val="Calibri"/></font>
    <font><sz val="11"/><b/><name val="Calibri"/></font>
  </fonts>
  <fills>
    <fill><patternFill patternType="none"/></fill>
    <fill><patternFill patternType="gray125"/></fill>
  </fills>
  <borders>
    <border><left/><right/><top/><bottom/><diagonal/></border>
  </borders>
  <cellStyleXfs count="1">
    <xf numFmtId="0" fontId="0" fillId="0" borderId="0"/>
  </cellStyleXfs>
  <cellXfs>
    <xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>
    <xf numFmtId="0" fontId="1" fillId="0" borderId="0" xfId="0" applyFont="1"/>
  </cellXfs>
</styleSheet>''';

    // ── Static XML files ───────────────────────────────────────────────────
    const contentTypes = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
  <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
  <Override PartName="/xl/sharedStrings.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sharedStrings+xml"/>
  <Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>
</Types>''';

    const relsXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
</Relationships>''';

    const workbookXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"
          xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <sheets>
    <sheet name="Trips" sheetId="1" r:id="rId1"/>
  </sheets>
</workbook>''';

    const workbookRels = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>
  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/sharedStrings" Target="sharedStrings.xml"/>
  <Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
</Relationships>''';

    // ── Build ZIP (xlsx) ───────────────────────────────────────────────────
    final archive = Archive();

    void addFile(String name, String content) {
      final bytes = utf8.encode(content);
      archive.addFile(ArchiveFile(name, bytes.length, bytes));
    }

    addFile('[Content_Types].xml', contentTypes);
    addFile('_rels/.rels', relsXml);
    addFile('xl/workbook.xml', workbookXml);
    addFile('xl/_rels/workbook.xml.rels', workbookRels);
    addFile('xl/worksheets/sheet1.xml', sheetBuf.toString());
    addFile('xl/sharedStrings.xml', ssBuf.toString());
    addFile('xl/styles.xml', stylesXml);

    final zipBytes = ZipEncoder().encode(archive);
    return Uint8List.fromList(zipBytes!);
  }

  /// Converts a 0-based column index to Excel column letter(s): 0→A, 25→Z, 26→AA
  static String _colLetter(int col) {
    String result = '';
    col++;
    while (col > 0) {
      col--;
      result = String.fromCharCode(65 + col % 26) + result;
      col ~/= 26;
    }
    return result;
  }

  static List<List<dynamic>> parseXlsx(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
    
    ArchiveFile? sharedStringsFile;
    ArchiveFile? sheetFile;
    
    for (final file in archive) {
      if (file.name == 'xl/sharedStrings.xml') {
        sharedStringsFile = file;
      } else if (file.name == 'xl/worksheets/sheet1.xml') {
        sheetFile = file;
      }
    }
    
    List<String> sharedStrings = [];
    if (sharedStringsFile != null) {
      final content = utf8.decode(sharedStringsFile.content as List<int>, allowMalformed: true);
      final siRegExp = RegExp(r'<si>(.*?)</si>', dotAll: true);
      final tRegExp = RegExp(r'<t\b[^>]*>(.*?)</t>', dotAll: true);
      for (final siMatch in siRegExp.allMatches(content)) {
        final siContent = siMatch.group(1) ?? '';
        final tMatches = tRegExp.allMatches(siContent);
        final buffer = StringBuffer();
        for (final tMatch in tMatches) {
          buffer.write(tMatch.group(1) ?? '');
        }
        sharedStrings.add(_decodeXmlEntities(buffer.toString()));
      }
    }
    
    List<List<dynamic>> rows = [];
    if (sheetFile != null) {
      final content = utf8.decode(sheetFile.content as List<int>, allowMalformed: true);
      
      final rowRegExp = RegExp(r'<row\b[^>]*>(.*?)</row>', dotAll: true);
      final cellRegExp = RegExp(r'<c\b[^>]*>(.*?)</c>', dotAll: true);
      final rAttrRegExp = RegExp(r'\br="([A-Z]+[0-9]+)"');
      final tAttrRegExp = RegExp(r'\bt="([^"]+)"');
      final vRegExp = RegExp(r'<v>(.*?)</v>', dotAll: true);
      final rowRAttrRegExp = RegExp(r'\br="([0-9]+)"');
      
      for (final rowMatch in rowRegExp.allMatches(content)) {
        final rowContent = rowMatch.group(1) ?? '';
        final rowTag = rowMatch.group(0) ?? '';
        
        int rowIndex = rows.length + 1;
        final rowRMatch = rowRAttrRegExp.firstMatch(rowTag);
        if (rowRMatch != null) {
          rowIndex = int.tryParse(rowRMatch.group(1) ?? '') ?? rowIndex;
        }
        
        while (rows.length < rowIndex) {
          rows.add([]);
        }
        
        final currentRow = rows[rowIndex - 1];
        
        for (final cellMatch in cellRegExp.allMatches(rowContent)) {
          final cellContent = cellMatch.group(1) ?? '';
          final cellTag = cellMatch.group(0) ?? '';
          
          final rMatch = rAttrRegExp.firstMatch(cellTag);
          if (rMatch == null) continue;
          
          final cellRef = rMatch.group(1)!;
          final refMatch = RegExp(r'^([A-Z]+)([0-9]+)$').firstMatch(cellRef);
          if (refMatch == null) continue;
          
          final colLetters = refMatch.group(1)!;
          final colIndex = _columnRefToIndex(colLetters);
          
          final tMatch = tAttrRegExp.firstMatch(cellTag);
          final isSharedString = tMatch != null && tMatch.group(1) == 's';
          
          final vMatch = vRegExp.firstMatch(cellContent);
          String value = '';
          if (vMatch != null) {
            final rawVal = vMatch.group(1) ?? '';
            if (isSharedString) {
              final idx = int.tryParse(rawVal) ?? -1;
              if (idx >= 0 && idx < sharedStrings.length) {
                value = sharedStrings[idx];
              } else {
                value = rawVal;
              }
            } else {
              value = _decodeXmlEntities(rawVal);
            }
          }
          
          while (currentRow.length <= colIndex) {
            currentRow.add('');
          }
          currentRow[colIndex] = value;
        }
      }
    }
    
    return rows.where((row) => row.any((cell) => cell.toString().trim().isNotEmpty)).toList();
  }
  
  static int _columnRefToIndex(String ref) {
    int col = 0;
    for (int i = 0; i < ref.length; i++) {
      col = col * 26 + (ref.codeUnitAt(i) - 65 + 1);
    }
    return col - 1;
  }
  
  static String _decodeXmlEntities(String input) {
    return input
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'");
  }
}
