import pdfplumber
import re
from datetime import datetime
from typing import Dict, List, Tuple

class PenetrationTestReportValidator:
    """
    Validates required header fields in Penetration Testing Report PDFs
    """
    
    def __init__(self):
        self.required_fields = {
            'Preliminary Date': {'required': True, 'type': 'date'},
            'Report Issued Date': {'required': True, 'type': 'date'},
            'Report Status': {'required': True, 'type': 'text', 'expected_value': 'Preliminary Report'},
            'VA Manager': {'required': True, 'type': 'text'},
            'IP Address': {'required': True, 'type': 'ip'}
        }
    
    def extract_field_value(self, text: str, field_name: str) -> str:
        """
        Extract field value using multiple pattern matching strategies
        """
        patterns = [
            # Pattern 1: Field name followed by value on same line
            rf"{re.escape(field_name)}\s*[:\s]+([^\n\r]+)",
            # Pattern 2: Field name with value in next cell/line
            rf"{re.escape(field_name)}[^\n]*\n\s*([^\n\r]+)",
            # Pattern 3: More flexible matching
            rf"{re.escape(field_name)}.*?([A-Za-z0-9\/\-\.\s:]+)"
        ]
        
        for pattern in patterns:
            match = re.search(pattern, text, re.IGNORECASE | re.MULTILINE)
            if match:
                value = match.group(1).strip()
                # Clean up common artifacts
                value = re.sub(r'^\s*[:\-\s]+', '', value)  # Remove leading colons/dashes
                value = re.sub(r'\s+', ' ', value)  # Normalize whitespace
                if value and len(value) > 1:  # Ensure meaningful content
                    return value
        
        return ""
    
    def validate_date(self, date_str: str) -> Tuple[bool, str]:
        """
        Validate date format - accepts common formats like MM/DD/YYYY, M/D/YYYY
        """
        if not date_str:
            return False, "Date field is empty"
        
        date_patterns = [
            r'^\d{1,2}/\d{1,2}/\d{4}$',  # M/D/YYYY or MM/DD/YYYY
            r'^\d{1,2}-\d{1,2}-\d{4}$',  # M-D-YYYY or MM-DD-YYYY
            r'^\d{4}-\d{1,2}-\d{1,2}$'   # YYYY-M-D or YYYY-MM-DD
        ]
        
        for pattern in date_patterns:
            if re.match(pattern, date_str.strip()):
                return True, "Valid date format"
        
        return False, f"Invalid date format: '{date_str}'"
    
    def validate_ip_address(self, ip_str: str) -> Tuple[bool, str]:
        """
        Validate IP address format
        """
        if not ip_str:
            return False, "IP Address field is empty"
        
        # Basic IPv4 pattern
        ip_pattern = r'^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$'
        
        if re.match(ip_pattern, ip_str.strip()):
            # Additional validation for valid IP ranges
            parts = ip_str.strip().split('.')
            if all(0 <= int(part) <= 255 for part in parts):
                return True, "Valid IP address"
            else:
                return False, f"IP address out of valid range: '{ip_str}'"
        
        return False, f"Invalid IP address format: '{ip_str}'"
    
    def validate_report_status(self, status_str: str, expected: str) -> Tuple[bool, str]:
        """
        Validate report status matches expected value
        """
        if not status_str:
            return False, "Report Status field is empty"
        
        if status_str.strip().lower() == expected.lower():
            return True, f"Report status matches expected value: '{expected}'"
        
        return False, f"Report status mismatch. Expected: '{expected}', Found: '{status_str}'"
    
    def validate_text_field(self, text_str: str, field_name: str) -> Tuple[bool, str]:
        """
        Validate that text field is not empty and has meaningful content
        """
        if not text_str or len(text_str.strip()) < 2:
            return False, f"{field_name} field is empty or too short"
        
        return True, f"{field_name} field contains valid text"
    
    def validate_pdf(self, pdf_path: str) -> Dict:
        """
        Main validation function - returns detailed results
        """
        results = {
            'file_path': pdf_path,
            'validation_passed': False,
            'fields': {},
            'errors': [],
            'warnings': []
        }
        
        try:
            with pdfplumber.open(pdf_path) as pdf:
                # Extract text from first page
                first_page = pdf.pages[0]
                text = first_page.extract_text()
                
                if not text:
                    results['errors'].append("Could not extract text from PDF")
                    return results
                
                # Validate each required field
                all_fields_valid = True
                
                for field_name, field_config in self.required_fields.items():
                    field_value = self.extract_field_value(text, field_name)
                    
                    field_result = {
                        'value': field_value,
                        'is_valid': False,
                        'message': ''
                    }
                    
                    # Perform field-specific validation
                    if field_config['type'] == 'date':
                        is_valid, message = self.validate_date(field_value)
                    elif field_config['type'] == 'ip':
                        is_valid, message = self.validate_ip_address(field_value)
                    elif field_config['type'] == 'text' and 'expected_value' in field_config:
                        is_valid, message = self.validate_report_status(field_value, field_config['expected_value'])
                    else:
                        is_valid, message = self.validate_text_field(field_value, field_name)
                    
                    field_result['is_valid'] = is_valid
                    field_result['message'] = message
                    results['fields'][field_name] = field_result
                    
                    if not is_valid:
                        all_fields_valid = False
                        results['errors'].append(f"{field_name}: {message}")
                
                results['validation_passed'] = all_fields_valid
                
        except Exception as e:
            results['errors'].append(f"Error processing PDF: {str(e)}")
        
        return results
    
    def generate_report(self, validation_results: Dict) -> str:
        """
        Generate a human-readable validation report
        """
        report = []
        report.append("=" * 60)
        report.append("PDF HEADER VALIDATION REPORT")
        report.append("=" * 60)
        report.append(f"File: {validation_results['file_path']}")
        report.append(f"Overall Status: {'✅ PASSED' if validation_results['validation_passed'] else '❌ FAILED'}")
        report.append("")
        
        report.append("FIELD VALIDATION RESULTS:")
        report.append("-" * 40)
        
        for field_name, field_data in validation_results['fields'].items():
            status = "✅" if field_data['is_valid'] else "❌"
            report.append(f"{status} {field_name}")
            report.append(f"   Value: '{field_data['value']}'")
            report.append(f"   Status: {field_data['message']}")
            report.append("")
        
        if validation_results['errors']:
            report.append("ERRORS:")
            report.append("-" * 40)
            for error in validation_results['errors']:
                report.append(f"• {error}")
        
        return "\n".join(report)


# Example usage
def main():
    """
    Example usage of the validator
    """
    validator = PenetrationTestReportValidator()
    
    # Validate a PDF file
    pdf_path = "path/to/your/penetration_test_report.pdf"
    results = validator.validate_pdf(pdf_path)
    
    # Print detailed report
    print(validator.generate_report(results))
    
    # Check if validation passed
    if results['validation_passed']:
        print("\n🎉 All required fields are properly filled!")
    else:
        print(f"\n⚠️  Validation failed. {len(results['errors'])} errors found.")
        return False
    
    return True

if __name__ == "__main__":
    main()
