# BikeTrack website

Source lives in `src/`; `scripts/build-production.mjs` generates the public site in `../docs/`. GitHub Pages publishes `main:/docs` at [youssef2430.github.io/BikeTrack](https://youssef2430.github.io/BikeTrack/).

```sh
cd website
npm run dev
```

Open http://127.0.0.1:4173. Node.js and Python 3 are required; there are no npm dependencies.

Run `npm run build` and commit both source and generated files when publishing changes. Privacy and support pages are also maintained in `src/`. All images, fonts, and their licenses live in `src/assets/`: Archivo (variable width and weight) for type and Doto for dot-matrix details, both under the SIL Open Font License. The build needs no design drafts or private release records.

Screenshots are real Watch app screens showing simulated demo data; replace the `screen-*.png` files when the app's look changes. The site currently says “Coming to the App Store”; update its download link and the root README when the public listing becomes available.
