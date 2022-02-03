#!/usr/bin/env node

import babel from '@babel/core'
import esbuild from 'esbuild'
import coffeeScriptPlugin from 'esbuild-coffeescript'
import fsPromises from 'fs/promises'

const outdir = 'app/assets/builds'
const outfileEsbuild = 'application_es6.js'
const outfileEsbuildPath = `${outdir}/${outfileEsbuild}`
const outfileBabel = 'application.js'
const outfileBabelPath = `${outdir}/${outfileBabel}`

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
      const inputSourceMapString = await fsPromises.readFile(`${outfileEsbuildPath}.map`)
      const options = {
        presets: [
          ['@babel/preset-env']
        ],
        inputSourceMap: JSON.parse(inputSourceMapString),
        sourceMaps: true
      }
      const outEsbuild = await fsPromises.readFile(outfileEsbuildPath)
      const result = await babel.transformAsync(outEsbuild, options)

      return Promise.all([
        fsPromises.writeFile(outfileBabelPath, `${result.code}\n//# sourceMappingURL=${outfileBabel}.map`),
        fsPromises.writeFile(`${outfileBabelPath}.map`, JSON.stringify(result.map))
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
  outfile: outfileEsbuildPath,
  plugins: [coffeeScriptPlugin({ bare: true }), babelOnEnd, analyzeOnEnd],
  resolveExtensions: ['.coffee', '.js'],
  sourcemap: true,
  watch: options.watch
})
