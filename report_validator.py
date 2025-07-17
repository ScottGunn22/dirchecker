import pdfplumber
import re
import logging
from datetime import datetime
from typing import Dict, Tuple, List

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s %(levelname)s: %(message)s')
logger = logging.getLogger(__name__)

class PenetrationTestReportValidator:
    """
    Refactored PDF header validator with table extraction and improved regex anchoring.
    """
    def __init__(self):
        # Define which fields are required and their types
        self.required_fields = {
            'Preliminary Date':    {'required': True, 'type': 'date'},
            'Report Issued Date':  {'required': True, 'type': 'date'},
            'Report Status':       {'required': True, 'type': 'status', 'expected': 'Preliminary Report'},
            'VA Manager':          {'required': True, 'type': 'text'},
            'IP Address':          {'required': True, 'type': 'ip'}
        }

        # Custom anchored regex for precise extraction
        self.custom_patterns = {
            'Preliminary Date':    r'Preliminary Date\s*[:]?\s*(\d{1,2}/\d{1,2}/\d{4})\b',
            'Report Issued Date':  r'Report Issued Date\s*[:]?\s*(\d{1,2}/\d{1,2}/\d{4})\b',
            'Report Status':       [
                                      r'Report Status\s*[:]?\s*(Preliminary Report)\b',
                                      r'Report Status\s+(Preliminary Report)\b'
                                    ],
            'VA Manager':          r'(?:CIVA Manager|VA Manager)\s*[:]?\s*([A-Za-z &]+?)\s*(?=\n|$)'
        }

        # Generic fallback patterns if table extraction fails
        self.generic_patterns = [
            r"{field}\s*[:\s]+([^\n\r]+)",
            r"{field}[^\n]*\n\s*([^\n\r]+)"
        ]

        # Map types to validator functions
        self.validators = {
            'date':   self._validate_date,
            'status': self._validate_status,
            'text':   self._validate_text,
            'ip':     self._validate_ips
        }

    def _extract_table_map(self, page) -> Dict[str, str]:
        """
        Attempt to extract headers as table rows using extract_tables(): first cell -> second cell.
        """
        table_map = {}
        tables = page.extract_tables() or []
        for table in tables:
            for row in table:
                if row and len(row) >= 2:
                    key = row[0] or ''
                    val = row[1] or ''
                    table_map[key.strip()] = val.strip()
        return table_map

    def extract_field_value(self, page_text: str, page, field: str) -> str:
        # 1) Try table-based map
        table_map = self._extract_table_map(page)
        if field in table_map and table_map[field]:
            logger.debug(f"[table] {field} -> {table_map[field]}")
            return table_map[field]

        # 2) IP Address special: grab block until next header
        if field == 'IP Address':
            m = re.search(r'IP Address\s*[:]?\s*([\s\S]+?)\nURL Tested', page_text)
            if m:
                return m.group(1).strip()

        # 3) Anchored custom regex
        pats = self.custom_patterns.get(field)
        if pats:
            if isinstance(pats, list):
                for pat in pats:
                    m = re.search(pat, page_text, re.IGNORECASE)
                    if m:
                        return m.group(1).strip()
            else:
                m = re.search(pats, page_text, re.IGNORECASE)
                if m:
                    return m.group(1).strip()

        # 4) Generic fallback
        for pat in self.generic_patterns:
            regex = pat.format(field=re.escape(field))
            m = re.search(regex, page_text, re.IGNORECASE | re.MULTILINE)
            if m:
                val = m.group(1).strip()
                val = re.split(r"\b(?:" + "|".join(map(re.escape, self.required_fields.keys())) + r")\b", val)[0].strip()
                return val

        return ''

    def _validate_date(self, date_str: str) -> Tuple[bool, str]:
        """
        Validate date against a set of common formats via datetime.strptime
        """
        if not date_str:
            return False, "Date field is empty"

        formats = [
            "%m/%d/%Y",  # 02/14/2025
            "%m-%d-%Y",  # 02-14-2025
            "%Y-%m-%d",  # 2025-02-14
            "%Y/%m/%d",  # 2025/02/14
        ]
        for fmt in formats:
            try:
                datetime.strptime(date_str.strip(), fmt)
                return True, f"Parsed as {fmt}"
            except ValueError:
                continue

        return False, f"Unrecognized date format: '{date_str}'"

    def _validate_status(self, status_str: str, expected: str) -> Tuple[bool, str]:
        if not status_str:
            return False, "Status field is empty"
        if status_str.strip().lower() == expected.lower():
            return True, "Status matches expected"
        return False, f"Expected '{expected}', found '{status_str}'"

    def _validate_text(self, text_str: str, field: str) -> Tuple[bool, str]:
        if not text_str or len(text_str.strip()) < 2:
            return False, f"{field} is missing or too short"
        return True, "Valid text"

    def _validate_ips(self, ip_block: str) -> Tuple[bool, str]:
        # extract all dotted quads
        ips = re.findall(r'\b(?:\d{1,3}\.){3}\d{1,3}\b', ip_block)
        if not ips:
            return False, "No IPs found"
        bad = [ip for ip in ips if any(int(o) not in range(256) for o in ip.split('.'))]
        if bad:
            return False, f"Out-of-range IPs: {', '.join(bad)}"
        return True, f"IPs found: {', '.join(ips)}"

    def validate_pdf(self, pdf_path: str) -> Dict:
        results = {
            'file': pdf_path,
            'passed': True,
            'fields': {},
            'errors': []
        }
        try:
            with pdfplumber.open(pdf_path) as pdf:
                page = pdf.pages[0]
                text = page.extract_text() or ''

                for field, cfg in self.required_fields.items():
                    val = self.extract_field_value(text, page, field)
                    typ = cfg['type']
                    validator = self.validators[typ]

                    if typ == 'status':
                        ok, msg = validator(val, cfg['expected'])
                    else:
                        ok, msg = validator(val) if typ != 'text' else validator(val, field)

                    results['fields'][field] = {'value': val, 'valid': ok, 'msg': msg}
                    if not ok:
                        results['passed'] = False
                        results['errors'].append(f"{field}: {msg}")

        except Exception as e:
            logger.error(f"Failed to open or parse PDF: {e}")
            results['passed'] = False
            results['errors'].append(str(e))

        return results

    def generate_report(self, res: Dict) -> str:
        lines = ["PDF HEADER VALIDATION REPORT", "="*40]
        lines.append(f"File: {res['file']}")
        lines.append(f"Overall: {'PASSED' if res['passed'] else 'FAILED'}")
        lines.append("")
        for fld, d in res['fields'].items():
            status = '✅' if d['valid'] else '❌'
            lines.append(f"{status} {fld}: {d['value']} ({d['msg']})")
        if res['errors']:
            lines.append("\nErrors:")
            for e in res['errors']:
                lines.append(f" - {e}")
        return "\n".join(lines)


if __name__ == "__main__":
    import sys
    if len(sys.argv) != 2:
        print(f"Usage: {sys.argv[0]} <report.pdf>")
        sys.exit(1)

    validator = PenetrationTestReportValidator()
    results = validator.validate_pdf(sys.argv[1])
    print(validator.generate_report(results))
    if not results['passed']:
        sys.exit(1)
