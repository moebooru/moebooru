#!/usr/bin/env node

import babel from '@babel/core'
import esbuild from 'esbuild'
import coffeeScriptPlugin from 'esbuild-coffeescript'
import fsPromises from 'fs/promises'

const outfileName = 'application.js'
const outfileEsbuild = `tmp/${outfileName}`
const outfileBabel = `app/assets/builds/${outfileName}`

const analyzeOnEnd = {
  name: 'analyzeOnEnd',
  setup (build) {
    build.onEnd(async (result) => {
      if (options.analyze) {
        const analyzeResult = await esbuild.analyzeMetafile(result.metafile)

        console.log(analyzeResult)
      }
    })
  }
}

const babelOnEnd = {
  name: 'babelOnEnd',
  setup (build) {
    build.onEnd(async () => {
      const options = {
        presets: [
          ['@babel/preset-env']
        ],
        sourceMaps: true
      }
      const outEsbuild = await fsPromises.readFile(outfileEsbuild)
      const result = await babel.transformAsync(outEsbuild, options)

      return Promise.all([
        fsPromises.writeFile(outfileBabel, `${result.code}\n//# sourceMappingURL=${outfileName}.map`),
        fsPromises.writeFile(`${outfileBabel}.map`, JSON.stringify(result.map))
      ])
    })
  }
}

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
  plugins: [coffeeScriptPlugin({ bare: true }), babelOnEnd, analyzeOnEnd],
  resolveExtensions: ['.coffee', '.js'],
  sourcemap: 'inline',
  watch: options.watch
})
