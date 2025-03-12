# Eureka
_A place to play and explore in the bits and bytes of coding_

## Code Pens
To start codepen server:
`python serve.py`
 - Will serve directory on port 8000

### Random APIs
https://api.chucknorris.io/


To start a new project with Vite
`npm create vite@latest`


### Notes on creating custom linting rules:
Lint Rule inspection/creation tool
https://astexplorer.net/


- Install your custom plugin as a file dev dependency
- Import the package to eslint.config.mjs
- Add the package as 
   ```
   plugins: {
     custom: <custom package>
   },
   rules: { ... }
- Add rules with the name `custom/<rule name>`
- To test, call `NODE_OPTIONS="$NOTE_OPTIONS --experimental-vm-modules" npx jest single-line-imports --verbose `