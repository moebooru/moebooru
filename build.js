#!/usr/bin/env node

import babel from '@babel/core'
import { createHash } from 'crypto'
import esbuild from 'esbuild'
import coffeeScriptPlugin from 'esbuild-coffeescript'
import fsPromises from 'fs/promises'

const outfileName = 'application.jsout'
const outfileEsbuild = `tmp/${outfileName}`
const outfileBabel = `app/assets/builds/${outfileName}`

const plugins = [
  coffeeScriptPlugin({
    bare: true,
    inlineMap: true
  }),
  {
    name: 'babel',
    setup (build) {
      build.onEnd(async () => {
        const options = {
          minified: true,
          presets: [
            ['@babel/preset-env']
          ],
          sourceMaps: true
        }
        const outEsbuild = await fsPromises.readFile(outfileEsbuild)
        const result = await babel.transformAsync(outEsbuild, options)
        result.map.sources = result.map.sources
          // CoffeeScript sourcemap and Esbuild sourcemap combined generates duplicated source paths
          .map((path) => path.replace(/\.\.\/app\/javascript(\/.+)?\/app\/javascript\//, '../app/javascript/'))
        const resultMap = JSON.stringify(result.map)
        const resultMapHash = createHash('sha256').update(resultMap).digest('hex')

        return Promise.all([
          // add hash so it matches sprocket output
          fsPromises.writeFile(outfileBabel, `${result.code}\n//# sourceMappingURL=${outfileName}-${resultMapHash}.map`),
          fsPromises.writeFile(`${outfileBabel}.map`, JSON.stringify(result.map))
        ])
      })
    }
  },
  {
    name: 'analyze',
    setup (build) {
      build.onEnd(async (result) => {
        if (options.analyze) {
          const analyzeResult = await esbuild.analyzeMetafile(result.metafile)

          console.log(analyzeResult)
        }
      })
    }
  },
]

const args = process.argv.slice(2)
const options = {
  watch: args.includes('--watch'),
  analyze: args.includes('--analyze')
}

esbuild.build({
  bundle: true,
  entryPoints: ['app/javascript/application.coffee'],
  metafile: options.analyze,
  nodePaths: ['app/javascript'],
  outfile: outfileEsbuild,
  plugins,
  resolveExtensions: ['.coffee', '.js'],
  sourcemap: 'inline',
  watch: options.watch
})
