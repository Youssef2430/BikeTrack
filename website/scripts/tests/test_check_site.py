import importlib.util
from pathlib import Path
import tempfile
import unittest


spec = importlib.util.spec_from_file_location("check_site", Path(__file__).parents[1] / "check-site.py")
site = importlib.util.module_from_spec(spec)
spec.loader.exec_module(site)


class SiteValidationTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        self.home = f'<link rel="canonical" href="{site.BASE_URL}"><main id="main"></main>'
        (self.root / "index.html").write_text(self.home)
        (self.root / "privacy.html").write_text('<a href="./#main">Home</a>')
        (self.root / "support.html").write_text('<a href="privacy.html">Privacy</a>')
        urls = "".join(f"<url><loc>{site.BASE_URL}{name}</loc></url>" for name in ("", "privacy.html", "support.html"))
        (self.root / "sitemap.xml").write_text(f"<urlset>{urls}</urlset>")

    def add_markup(self, markup):
        (self.root / "index.html").write_text(self.home + markup)

    def test_valid_site_and_external_links(self):
        self.add_markup('<a href="https://github.com/yssf-c/BikeTrack">GitHub</a>')
        self.assertEqual(site.validate(self.root), [])

    def test_missing_asset(self):
        self.add_markup('<img src="missing.png">')
        self.assertTrue(any("missing link or asset" in error for error in site.validate(self.root)))

    def test_missing_fragment(self):
        self.add_markup('<a href="#missing">Broken</a>')
        self.assertTrue(any("missing fragment" in error for error in site.validate(self.root)))

    def test_css_font_reference(self):
        (self.root / "style.css").write_text("@font-face { src: url('missing.woff2'); }")
        self.assertTrue(any("missing.woff2" in error for error in site.validate(self.root)))

    def test_project_base_path_required(self):
        self.add_markup('<a href="/privacy.html">Broken</a>')
        self.assertTrue(any("escapes" in error for error in site.validate(self.root)))

    def test_previous_pages_account(self):
        self.add_markup('<a href="https://previous-account.github.io/BikeTrack/">Old site</a>')
        self.assertTrue(any("outdated Pages URL" in error for error in site.validate(self.root)))

    def test_bad_canonical_and_sitemap(self):
        (self.root / "index.html").write_text("<main></main>")
        (self.root / "sitemap.xml").write_text("<urlset/>")
        errors = site.validate(self.root)
        self.assertTrue(any("canonical" in error for error in errors))
        self.assertTrue(any("sitemap" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
