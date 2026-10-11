# BikeTrack website

The production site combines Cadence's condensed typography and editorial layout with Volt's black and lime palette.

Live: https://youssef2430.github.io/BikeTrack/

## Develop and publish

```sh
cd website
npm run dev
```

Open http://127.0.0.1:4173. Node.js and Python 3 are required; no npm dependencies need installing.

`npm run build` copies the production source and assets into `../docs/`. GitHub Pages publishes `main:/docs`; commit the generated files with source changes and push to `main` to deploy. The build preserves the existing documentation, privacy policy, and support page.

- `production/index.html`: production content, accessible controls, and page structure.
- `production/site.css`: visual system, responsive layouts, and reduced-motion support.
- `production/site.js`: screen tabs, heart-rate demo, navigation, motion controls, and transitions.
- `production/assets/`: local fonts and social image.
- `production/legal.css`: shared presentation for the existing privacy and support pages.
- `scripts/build-production.mjs`: dependency-free static build.

All runtime assets are served locally. Motion can be paused in the header; the preference persists in the browser. System reduced-motion preferences are also respected. Screen tabs support keyboard navigation, and FAQs retain native details semantics.

## Original design concepts

```sh
npm run dev:concepts
```

Open http://127.0.0.1:4174 to view the original comparison gallery and six directions: Volt, Forma, Cadence, Grove, Metric, and Nocturne. The gallery includes persistent shortlisting and side-by-side comparison.

`npm run build:concepts` regenerates the concept HTML from `scripts/build.mjs`. Concept CSS, JavaScript, and assets are authored directly in `dist/` and retained by that build.

## Product content and assets

Copy is grounded in the app source, root README, and App Store metadata. The app is currently awaiting Apple review according to `AppStore/release-status.json`, so the production site says “Coming to the App Store” and links to the GitHub project. Replace the launch CTA with the public App Store URL after release.

App screens come from `AppStore/screenshots/en-US/` and are labeled as demo data. Watch frames and bands are illustrative CSS. Fonts include their SIL Open Font Licenses; the app icon includes the Phosphor MIT attribution. Shared app images and licenses are copied from `dist/assets/` by the production build.

## Verification

The production page was checked in the T3 collaborative browser at mobile, tablet, and desktop widths. Checks covered horizontal overflow, image loading, readout spacing, mobile navigation, keyboard-operated screen tabs, zone selection, FAQ expansion, and persistence of the motion preference. The app's training-zone boundaries were checked against its Swift implementation. See `production-verification.json` for recorded browser checks; `verification.json` covers the original concept gallery.
