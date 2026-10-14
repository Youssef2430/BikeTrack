"""Validate the generated Pages site without network access or dependencies."""

from html.parser import HTMLParser
from pathlib import Path
import re
from urllib.parse import unquote, urljoin, urlsplit
import xml.etree.ElementTree as ET


BASE_URL = "https://yssf-c.github.io/BikeTrack/"


class Page(HTMLParser):
    def __init__(self, text):
        super().__init__(convert_charrefs=True)
        self.ids = set()
        self.links = []
        self.canonical = []
        self.feed(text)

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if "id" in attrs:
            self.ids.add(attrs["id"])
        for key in ("href", "src", "poster"):
            if attrs.get(key):
                self.links.append(attrs[key])
        if tag == "link" and "canonical" in attrs.get("rel", "").split():
            self.canonical.append(attrs.get("href"))
        if tag == "meta" and attrs.get("property") in ("og:url", "og:image"):
            self.links.append(attrs.get("content", ""))


def validate(root):
    root = Path(root).resolve()
    pages = {file: Page(file.read_text()) for file in root.rglob("*.html")}
    errors = []
    base = urlsplit(BASE_URL)

    def check_link(source, link):
        url = urlsplit(urljoin(BASE_URL + source.relative_to(root).as_posix(), link))
        if url.netloc != base.netloc:
            # A previous account's Pages links must not silently pass as external.
            if url.netloc.endswith(".github.io") and url.path.startswith(base.path):
                errors.append(f"{source.name}: outdated Pages URL: {link}")
            return
        if not url.path.startswith(base.path):
            errors.append(f"{source.name}: URL escapes the /BikeTrack/ site: {link}")
            return
        target = (root / unquote(url.path[len(base.path):])).resolve()
        if not target.is_relative_to(root):
            errors.append(f"{source.name}: URL escapes the site directory: {link}")
            return
        if target.is_dir():
            target /= "index.html"
        if not target.is_file():
            errors.append(f"{source.name}: missing link or asset: {link}")
        elif url.fragment and target in pages and unquote(url.fragment) not in pages[target].ids:
            errors.append(f"{source.name}: missing fragment: {link}")

    for file, page in pages.items():
        for link in page.links:
            check_link(file, link)
    for file in root.rglob("*.css"):
        for match in re.finditer(r"url\(\s*['\"]?([^'\")]+)['\"]?\s*\)", file.read_text()):
            check_link(file, match.group(1).strip())

    home = pages.get(root / "index.html")
    if home is None or home.canonical != [BASE_URL]:
        errors.append("index.html: expected exactly one canonical URL pointing to " + BASE_URL)
    for name in ("privacy.html", "support.html"):
        if root / name not in pages:
            errors.append(f"Missing required public page: {name}")
    try:
        sitemap = ET.parse(root / "sitemap.xml")
        urls = [node.text for node in sitemap.findall("{*}url/{*}loc")]
        expected = {BASE_URL + name for name in ("", "privacy.html", "support.html")}
        if set(urls) != expected or len(urls) != len(expected):
            errors.append("sitemap.xml: expected the current home, privacy, and support URLs")
        for url in urls:
            check_link(root / "sitemap.xml", url or "")
    except (OSError, ET.ParseError) as error:
        errors.append(f"Invalid sitemap.xml: {error}")
    return errors


if __name__ == "__main__":
    errors = validate(Path(__file__).resolve().parents[2] / "docs")
    if errors:
        raise SystemExit("\n".join(errors))
    print("Website links, assets, fragments, canonical URL, and sitemap are valid.")
