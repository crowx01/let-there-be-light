#!/usr/bin/env node
// let-there-be-light CLI - thin Node wrapper over setup.sh.
// Subcommands are delegated to the bash installer so a single source of truth
// handles state, checkpointing, and paths.

'use strict';
const { spawnSync } = require('child_process');
const path = require('path');
const fs = require('fs');

const ROOT = path.resolve(__dirname, '..');
const SETUP = path.join(ROOT, 'setup.sh');
const SKILLS_DIR = path.join(ROOT, 'skills');

const BOLD = '\x1b[1m', DIM = '\x1b[2m', CYN = '\x1b[36m', GRN = '\x1b[32m',
      YLW = '\x1b[33m', RED = '\x1b[31m', RST = '\x1b[0m';

function usage() {
  console.log(`${BOLD}let-there-be-light${RST}  interactive AI-orchestrator installer

${BOLD}Usage${RST} (github: form works without npm publish)
  npx --yes github:crowx01/let-there-be-light                install
  npx --yes github:crowx01/let-there-be-light add <skill>    install one shipped skill
  npx --yes github:crowx01/let-there-be-light list           list shipped skills
  npx --yes github:crowx01/let-there-be-light sync           re-run rules + skills sync
  npx --yes github:crowx01/let-there-be-light reset          clear checkpoint
  npx --yes github:crowx01/let-there-be-light --help         this help

${DIM}From a local clone: ./setup.sh <same-verbs>   or   node bin/cli.js <verbs>${RST}
`);
}

function listSkills() {
  if (!fs.existsSync(SKILLS_DIR)) {
    console.error(`${RED}✗${RST} skills/ not shipped in this install`);
    process.exit(1);
  }
  const names = fs.readdirSync(SKILLS_DIR).filter(n => {
    return fs.statSync(path.join(SKILLS_DIR, n)).isDirectory();
  }).sort();
  console.log(`\n${BOLD}shipped skills${RST}\n`);
  for (const n of names) {
    let desc = '';
    const skillMd = path.join(SKILLS_DIR, n, 'SKILL.md');
    if (fs.existsSync(skillMd)) {
      const src = fs.readFileSync(skillMd, 'utf8');
      const m = src.match(/^description:\s*(.+)$/m);
      if (m) desc = m[1].slice(0, 120);
    }
    console.log(`  ${BOLD}${n}${RST}  ${DIM}${desc}${RST}`);
  }
  console.log('');
}

function runSetup(args) {
  if (!fs.existsSync(SETUP)) {
    console.error(`${RED}✗${RST} setup.sh missing in ${ROOT}`);
    process.exit(1);
  }
  const r = spawnSync('bash', [SETUP, ...args], { stdio: 'inherit' });
  process.exit(r.status == null ? 1 : r.status);
}

const [, , cmd, ...rest] = process.argv;

switch (cmd) {
  case undefined:
  case 'install':
    runSetup([]);
    break;
  case '-h':
  case '--help':
  case 'help':
    usage();
    break;
  case 'list':
    listSkills();
    break;
  case 'add':
    if (!rest[0]) {
      console.error(`${RED}✗${RST} usage: npx --yes github:crowx01/let-there-be-light add <skill>`);
      listSkills();
      process.exit(2);
    }
    runSetup(['add', rest[0]]);
    break;
  case 'sync':
    runSetup(['sync']);
    break;
  case 'reset':
    runSetup(['reset']);
    break;
  default:
    console.error(`${RED}✗${RST} unknown command: ${cmd}`);
    usage();
    process.exit(2);
}
