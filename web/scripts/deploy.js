// Copies the built single-file web UI into the RemoboardKit resource bundle.
import { copyFileSync, mkdirSync, existsSync } from 'node:fs'
import { dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

const here = dirname(fileURLToPath(import.meta.url))
const root = resolve(here, '..', '..')

const siteDir = resolve(root, 'RemoboardKit', 'Resources', 'site')
mkdirSync(siteDir, { recursive: true })

const builtHtml = resolve(root, 'web', 'dist', 'index.html')
copyFileSync(builtHtml, resolve(siteDir, 'index.html'))
console.log('Deployed index.html ->', resolve(siteDir, 'index.html'))

const favicon = resolve(root, 'ObjcVersion', 'tokamak', 'bifrost', 'bifrost', 'http', 'site.bundle', 'favicon.ico')
if (existsSync(favicon)) {
  copyFileSync(favicon, resolve(siteDir, 'favicon.ico'))
  console.log('Deployed favicon.ico')
}
