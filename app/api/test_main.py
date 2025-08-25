import unittest
from unittest.mock import patch, MagicMock
import io

# Import the functions from your main application file
from main import _clean_text, extract_text

class TestTextFunctions(unittest.TestCase):

    def test_clean_text(self):
        """Tests the _clean_text function."""
        self.assertEqual(_clean_text("  hello   world  "), "hello world")
        self.assertEqual(_clean_text("\nleading and trailing\t"), "leading and trailing")
        self.assertEqual(_clean_text("no\nnew\nlines"), "no new lines")
        self.assertEqual(_clean_text("single string"), "single string")
        self.assertEqual(_clean_text(""), "")
        self.assertEqual(_clean_text(None), "")

    def test_extract_text_from_txt(self):
        """Tests extracting text from a .txt file."""
        content = b"This is a simple text file."
        text = extract_text("test.txt", content)
        self.assertEqual(text, "This is a simple text file.")

    def test_extract_text_from_html(self):
        """Tests extracting text from an .html file."""
        content = b"<html><head><title>Test</title></head><body><p>Hello World!</p></body></html>"
        text = extract_text("test.html", content)
        self.assertEqual(text, "Test Hello World!")

    @patch('main.PdfReader')
    def test_extract_text_from_pdf(self, MockPdfReader):
        """Tests extracting text from a .pdf file using a mock."""
        # Configure the mock to simulate a PDF with two pages
        mock_reader_instance = MockPdfReader.return_value
        mock_page1 = MagicMock()
        mock_page1.extract_text.return_value = "This is the first page."
        mock_page2 = MagicMock()
        mock_page2.extract_text.return_value = "This is the second page."
        mock_reader_instance.pages = [mock_page1, mock_page2]

        content = b"%PDF-1.4..."
        text = extract_text("document.pdf", content)

        # Check that the text from both pages is combined
        self.assertEqual(text, "This is the first page. This is the second page.")
        # Verify that PdfReader was called with the file content
        MockPdfReader.assert_called_once()
        self.assertIsInstance(MockPdfReader.call_args[0][0], io.BytesIO)

if __name__ == '__main__':
    unittest.main()
