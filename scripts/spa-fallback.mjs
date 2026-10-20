// GitHub Pages has no server-side routing. Serving index.html as 404.html
// lets links like /players/3 load the app, which then shows the right page.
import { copyFileSync } from 'node:fs'

copyFileSync('dist/index.html', 'dist/404.html')
console.log('Copied dist/index.html to dist/404.html')
