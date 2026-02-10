#!/usr/bin/env node

const { execSync } = require("child_process");
const fs = require("fs");
const path = require("path");

const PROJECT_NAME = "PixLit";
const BUILD_DIR = "build";
const VERSION = process.env.VERSION;
const ARCHIVE_PATH = path.join(BUILD_DIR, `${PROJECT_NAME}.xcarchive`);
const APP_PATH = path.join(
  ARCHIVE_PATH,
  "Products",
  "Applications",
  `${PROJECT_NAME}.app`,
);
const DMG_FILENAME = VERSION
  ? `${PROJECT_NAME}-${VERSION}.dmg`
  : `${PROJECT_NAME}.dmg`;
const DMG_PATH = path.join(BUILD_DIR, DMG_FILENAME);
const TEMP_DMG_DIR = path.join(BUILD_DIR, "dmg-temp");

function run(command, options = {}) {
  console.log(`Running: ${command}`);
  try {
    execSync(command, { stdio: "inherit", ...options });
  } catch (error) {
    console.error(`Failed to execute: ${command}`);
    process.exit(1);
  }
}

function main() {
  console.log(`\n📦 Building DMG for ${PROJECT_NAME}...\n`);

  // Check if archive exists
  if (!fs.existsSync(APP_PATH)) {
    console.error(`❌ App not found at ${APP_PATH}`);
    console.error('Run "make archive" first to create the archive.');
    process.exit(1);
  }

  // Clean up previous DMG
  if (fs.existsSync(DMG_PATH)) {
    fs.unlinkSync(DMG_PATH);
  }

  // Create temp directory for DMG contents
  if (fs.existsSync(TEMP_DMG_DIR)) {
    fs.rmSync(TEMP_DMG_DIR, { recursive: true });
  }
  fs.mkdirSync(TEMP_DMG_DIR, { recursive: true });

  // Copy app to temp directory
  console.log("📋 Copying app bundle...");
  run(`cp -R "${APP_PATH}" "${TEMP_DMG_DIR}/"`);

  // Re-sign app with ad-hoc identity and hardened runtime
  console.log("🔏 Signing app bundle...");
  run(
    `codesign --force --deep -s - --options runtime "${TEMP_DMG_DIR}/${PROJECT_NAME}.app"`,
  );

  // Create symbolic link to Applications folder
  console.log("🔗 Creating Applications symlink...");
  run(`ln -s /Applications "${TEMP_DMG_DIR}/Applications"`);

  // Create DMG
  console.log("💿 Creating DMG...");
  run(
    `hdiutil create -volname "${PROJECT_NAME}" -srcfolder "${TEMP_DMG_DIR}" -ov -format UDZO "${DMG_PATH}"`,
  );

  // Clean up
  console.log("🧹 Cleaning up...");
  fs.rmSync(TEMP_DMG_DIR, { recursive: true });

  console.log(`\n✅ DMG created successfully: ${DMG_PATH}\n`);
}

main();
