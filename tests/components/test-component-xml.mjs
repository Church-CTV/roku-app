/**
 * Component Tests: XML Structure Validation
 * 
 * Validates SceneGraph component XML files for:
 * - Well-formed XML structure
 * - Required interface fields
 * - Script URI references exist
 * - Component hierarchy compliance
 * - No orphaned .brs/.xml pairs
 */

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT_DIR = path.resolve(__dirname, '..');
const COMPONENTS_DIR = path.join(ROOT_DIR, '..', 'components');
const SOURCE_DIR = path.join(ROOT_DIR, '..', 'source');

export default async function runTests({ describe, it, assertions }) {
  const { equal, truthy, falsy, isString, isNumber, 
           isArray, includes, hasProperty, match, exists, 
           greaterThan } = assertions;

  // ============================================================
  // Helper: Parse simple XML
  // ============================================================

  function parseXmlComponent(xmlContent, filePath = '') {
    const errors = [];
    
    // Check well-formedness
    if (!xmlContent.includes('<?xml')) {
      errors.push('Missing XML declaration');
    }
    
    // Check root component element
    const componentMatch = xmlContent.match(/<component\s+name="(\w+)"\s+extends="(\w+)"/);
    if (!componentMatch) {
      errors.push(`Missing or invalid <component> root element in ${path.basename(filePath)}`);
    }
    
    return {
      name: componentMatch ? componentMatch[1] : null,
      extends: componentMatch ? componentMatch[2] : null,
      errors,
      content: xmlContent,
    };
  }

  function extractInterfaceFields(xmlContent) {
    const fields = [];
    const regex = /<field\s+id="(\w+)"\s+type="(\w+)"/g;
    let match;
    while ((match = regex.exec(xmlContent)) !== null) {
      fields.push({ id: match[1], type: match[2] });
    }
    return fields;
  }

  function extractScriptUris(xmlContent) {
    const uris = [];
    const regex = /<script\s+type="text\/brightscript"\s+uri="([^"]+)"/g;
    let match;
    while ((match = regex.exec(xmlContent)) !== null) {
      uris.push(match[1]);
    }
    return uris;
  }

  function extractChildNodes(xmlContent) {
    const nodes = [];
    const regex = /<(?:Poster|Label|Button|Group|Video|RowList|Grid|Overhang|TextInput|ContentNode)(?:\s+[^>]*)?>|<(\w+)\s+id="(\w+)"/g;
    let match;
    while ((match = regex.exec(xmlContent)) !== null) {
      nodes.push({ tag: match[1] || 'unknown', id: match[2] || null });
    }
    return nodes;
  }

  // ============================================================
  // Collect all component files
  // ============================================================

  function findComponentFiles() {
    const xmlFiles = [];
    const brsFiles = [];

    function scan(dir) {
      for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
        const fullPath = path.join(dir, entry.name);
        if (entry.isDirectory()) {
          scan(fullPath);
        } else if (entry.name.endsWith('.xml')) {
          xmlFiles.push(fullPath);
        } else if (entry.name.endsWith('.brs')) {
          brsFiles.push(fullPath);
        }
      }
    }

    scan(COMPONENTS_DIR);
    return { xmlFiles, brsFiles };
  }

  const { xmlFiles, brsFiles } = findComponentFiles();

  // ============================================================
  // Tests
  // ============================================================

  describe('XML Structure', () => {
    it('all XML files are well-formed', () => {
      for (const file of xmlFiles) {
        const content = fs.readFileSync(file, 'utf-8');
        const parsed = parseXmlComponent(content, file);
        
        if (parsed.errors.length > 0) {
          throw new Error(`${path.relative(ROOT_DIR, file)}: ${parsed.errors.join('; ')}`);
        }
      }
    });

    it('all component XML files have valid root elements', () => {
      for (const file of xmlFiles) {
        const content = fs.readFileSync(file, 'utf-8');
        const parsed = parseXmlComponent(content, file);
        truthy(parsed.name, `${path.basename(file)} should have component name`);
        truthy(parsed.extends, `${path.basename(file)} should have extends attribute`);
      }
    });

    it('component files have matching .brs files', () => {
      for (const xmlFile of xmlFiles) {
        if (path.basename(xmlFile).startsWith('Event')) continue; // Event XML files
        if (path.basename(xmlFile) === 'Analytics.xml') continue; // Pure data component
        if (path.basename(xmlFile) === 'CrashReporter.xml') continue; // Pure data component
        if (path.basename(xmlFile) === 'Global.xml') continue; // Pure interface component
        
        const brsFile = xmlFile.replace('.xml', '.brs');
        // Event XMLs don't need BRS companions
        const isEventFile = path.basename(xmlFile).includes('Event');
        if (!isEventFile) {
          truthy(fs.existsSync(brsFile), 
            `Missing .brs file for ${path.relative(ROOT_DIR, xmlFile)}`);
        }
      }
    });

    it('all components have valid extends chain', () => {
      const validBases = ['Scene', 'Node', 'Group', 'ContentNode', 'Video', 
                          'RowList', 'Grid', 'Task', 'Label', 'Button',
                          'TextInput', 'Poster', 'OptionList'];
      
      for (const file of xmlFiles) {
        
        const content = fs.readFileSync(file, 'utf-8');
        const parsed = parseXmlComponent(content, file);
        if (parsed.extends) {
          includes(validBases, parsed.extends, 
            `${path.basename(file)} extends "${parsed.extends}" which is not a valid base`);
        }
      }
    });
  });

  // ============================================================
  // Interface Field Tests
  // ============================================================

  describe('Interface Fields', () => {
    it('MainScene has required interface fields', () => {
      const mainScenePath = path.join(COMPONENTS_DIR, 'MainScene.xml');
      const content = fs.readFileSync(mainScenePath, 'utf-8');
      const fields = extractInterfaceFields(content);
      const fieldIds = fields.map(f => f.id);
      
      includes(fieldIds, 'deeplinkContentId');
      includes(fieldIds, 'deeplinkMediaType');
      includes(fieldIds, 'global');
    });

    it('Analytics has tracking interface', () => {
      const analyticsPath = path.join(COMPONENTS_DIR, 'Analytics.xml');
      const content = fs.readFileSync(analyticsPath, 'utf-8');
      const fields = extractInterfaceFields(content);
      const fieldIds = fields.map(f => f.id);
      
      includes(fieldIds, 'eventCount');
      includes(fieldIds, 'screenHistory');
    });

    it('CrashReporter has crash tracking interface', () => {
      const crashPath = path.join(COMPONENTS_DIR, 'CrashReporter.xml');
      const content = fs.readFileSync(crashPath, 'utf-8');
      const fields = extractInterfaceFields(content);
      const fieldIds = fields.map(f => f.id);
      
      includes(fieldIds, 'lastCrashTime');
      includes(fieldIds, 'crashCount');
    });

    it('all field types are valid BrightScript types', () => {
      const validTypes = ['string', 'integer', 'float', 'boolean', 'node', 'array', 'assocarray', 'dynamic', 'color', 'uri', 'intarray'];

      for (const file of xmlFiles) {
        const content = fs.readFileSync(file, 'utf-8');
        const fields = extractInterfaceFields(content);
        
        for (const field of fields) {
          includes(validTypes, field.type, 
            `${path.basename(file)} field "${field.id}" has invalid type "${field.type}"`);
        }
      }
    });
  });

  // ============================================================
  // Script Reference Tests
  // ============================================================

  describe('Script References', () => {
    it('all script URIs reference existing files', () => {
      for (const file of xmlFiles) {
        const content = fs.readFileSync(file, 'utf-8');
        const uris = extractScriptUris(content);
        const xmlDir = path.dirname(file);
        
        for (const uri of uris) {
          // Resolve relative to XML file location
          let scriptPath = path.resolve(xmlDir, uri);
          
          // Handle pkg:/ URIs
          if (uri.startsWith('pkg:/')) {
            scriptPath = path.resolve(ROOT_DIR, '..', uri.substring(5));
          }
          
          truthy(fs.existsSync(scriptPath), 
            `${path.basename(file)} references non-existent script: ${uri}`);
        }
      }
    });

    it('MainScene loads required scripts', () => {
      const mainScenePath = path.join(COMPONENTS_DIR, 'MainScene.xml');
      const content = fs.readFileSync(mainScenePath, 'utf-8');
      const uris = extractScriptUris(content);
      
      // App.brs is essential for utilities
      includes(uris, '../source/App.brs', 'MainScene should load App.brs');
      
      // ConfigLoader is needed for configuration
      includes(uris, '../source/ConfigLoader.bs', 'MainScene should load ConfigLoader.bs');
      
      // UI Logic modules
      includes(uris, 'UILogic/ScreenStackLogic.brs', 'MainScene should load ScreenStackLogic.brs');
      includes(uris, 'UILogic/ContentTaskLogic.brs', 'MainScene should load ContentTaskLogic.brs');
    });
  });

  // ============================================================
  // Component-Specific Tests
  // ============================================================

  describe('MainScene', () => {
    const mainScenePath = path.join(COMPONENTS_DIR, 'MainScene.xml');
    const content = fs.readFileSync(mainScenePath, 'utf-8');

    it('has loading indicator', () => {
      includes(content, 'id="loadingIndicator"', 'MainScene should have loading indicator');
    });

    it('has error screen', () => {
      includes(content, 'id="errorScreen"', 'MainScene should have error screen');
    });

    it('has welcome screen', () => {
      includes(content, 'id="welcomeScreen"', 'MainScene should have welcome screen');
    });

  });

  describe('SearchScreen', () => {
    const searchPath = path.join(COMPONENTS_DIR, 'SearchScreen.xml');
    const content = fs.readFileSync(searchPath, 'utf-8');

    it('has mini keyboard', () => {
      includes(content, 'MiniKeyboard', 'SearchScreen should have mini keyboard');
    });

    it('has search results list', () => {
      includes(content, 'SearchResults', 'SearchScreen should have search results');
    });

    it('has no results indicator', () => {
      includes(content, 'noResultsGroup', 'SearchScreen should have no results state');
    });
  });

  // ============================================================
  // Event Component Tests
  // ============================================================

  describe('Event Components', () => {
    it('AnalyticsEvent exists', () => {
      exists(path.join(COMPONENTS_DIR, 'AnalyticsEvent.xml'));
    });

    it('CrashEvent exists', () => {
      exists(path.join(COMPONENTS_DIR, 'CrashEvent.xml'));
    });

    it('ErrorEvent exists', () => {
      exists(path.join(COMPONENTS_DIR, 'ErrorEvent.xml'));
    });
  });

  // ============================================================
  // GridScreen Tests
  // ============================================================

  describe('GridScreen', () => {
    const gridPath = path.join(COMPONENTS_DIR, 'GridScreen');

    it('has GridScreen.xml', () => {
      exists(path.join(gridPath, 'GridScreen.xml'));
    });

    it('has GridScreen.brs', () => {
      exists(path.join(gridPath, 'GridScreen.brs'));
    });

    it('has exit dialog with all required elements', () => {
      const xmlContent = fs.readFileSync(path.join(gridPath, 'GridScreen.xml'), 'utf-8');

      includes(xmlContent, 'id="exitDialog"', 'GridScreen should have exitDialog group');
      includes(xmlContent, 'id="dialogBackdrop"', 'GridScreen should have dialogBackdrop');
      includes(xmlContent, 'id="dialogBox"', 'GridScreen should have dialogBox');
      includes(xmlContent, 'id="dialogTitle"', 'GridScreen should have dialogTitle');
      includes(xmlContent, 'id="dialogMessage"', 'GridScreen should have dialogMessage');
      includes(xmlContent, 'id="exitButton"', 'GridScreen should have exitButton');
      includes(xmlContent, 'id="exitButtonText"', 'GridScreen should have exitButtonText label');
    });

    it('exit button has non-empty text label', () => {
      const xmlContent = fs.readFileSync(path.join(gridPath, 'GridScreen.xml'), 'utf-8');
      const textMatch = xmlContent.match(/id="exitButtonText"[\s\S]*?text="([^"]*)"/);
      truthy(textMatch && textMatch[1].length > 0,
        'exitButtonText should have non-empty text');
      equal(textMatch[1], 'Exit', 'exitButtonText text should be "Exit"');
    });

    it('exit button uses a valid system font', () => {
      const xmlContent = fs.readFileSync(path.join(gridPath, 'GridScreen.xml'), 'utf-8');
      const fontMatch = xmlContent.match(/id="exitButtonText"[\s\S]*?font="([^"]*)"/);
      truthy(fontMatch, 'exitButtonText should have a font attribute');
      const validFonts = [
        'font:SmallSystemFont', 'font:SmallBoldSystemFont',
        'font:MediumSystemFont', 'font:MediumBoldSystemFont',
        'font:LargeSystemFont', 'font:LargeBoldSystemFont',
        'font:ExtraLargeSystemFont'
      ];
      includes(validFonts, fontMatch[1],
        `exitButtonText font "${fontMatch[1]}" should be a valid Roku system font`);
    });

    it('exit dialog title and message are set', () => {
      const xmlContent = fs.readFileSync(path.join(gridPath, 'GridScreen.xml'), 'utf-8');
      const titleMatch = xmlContent.match(/id="dialogTitle"[\s\S]*?text="([^"]*)"/);
      const msgMatch = xmlContent.match(/id="dialogMessage"[\s\S]*?text="([^"]*)"/);
      truthy(titleMatch && titleMatch[1].length > 0, 'dialogTitle should have non-empty text');
      truthy(msgMatch && msgMatch[1].length > 0, 'dialogMessage should have non-empty text');
    });

    it('exit dialog is hidden by default', () => {
      const xmlContent = fs.readFileSync(path.join(gridPath, 'GridScreen.xml'), 'utf-8');
      const dialogMatch = xmlContent.match(/id="exitDialog"([^>]*)>/);
      truthy(dialogMatch && dialogMatch[1].includes('visible="false"'),
        'exitDialog should be hidden by default');
    });

    it('GridScreen.brs handles OK key to exit app', () => {
      const brsContent = fs.readFileSync(path.join(gridPath, 'GridScreen.brs'), 'utf-8');
      truthy(brsContent.includes('OnKeyEvent'), 'GridScreen.brs should have OnKeyEvent handler');
      truthy(brsContent.includes('ExitApp'), 'GridScreen.brs should have ExitApp function');
      // Check that OK key is handled when dialog is visible
      truthy(brsContent.includes('LCase(key)') && brsContent.includes('"ok"') && brsContent.includes('dialogVisible'),
        'OnKeyEvent should handle OK when dialog is visible');
    });

    it('GridScreen.brs handles back key to show/hide exit dialog', () => {
      const brsContent = fs.readFileSync(path.join(gridPath, 'GridScreen.brs'), 'utf-8');
      truthy(brsContent.includes('ShowExitDialog'), 'GridScreen.brs should have ShowExitDialog');
      truthy(brsContent.includes('HideExitDialog'), 'GridScreen.brs should have HideExitDialog');
      // Back from (0,0) shows the dialog
      truthy(brsContent.includes('"back"'), 'OnKeyEvent should handle back key');
    });

    it('GridScreen.brs clears rowList focus when showing exit dialog', () => {
      const brsContent = fs.readFileSync(path.join(gridPath, 'GridScreen.brs'), 'utf-8');
      // ShowExitDialog should call m.rowList.SetFocus(false) to prevent rowList
      // from consuming key events (like OK) while the dialog is visible
      truthy(brsContent.includes('SetFocus(false)'),
        'ShowExitDialog should clear rowList focus to prevent key event swallowing');
    });

    it('GridScreen.brs ExitApp closes the roSGScreen', () => {
      const brsContent = fs.readFileSync(path.join(gridPath, 'GridScreen.brs'), 'utf-8');
      truthy(brsContent.includes('CloseChannel') || brsContent.includes('ExitApp'),
        'GridScreen should have a mechanism to close the channel');
    });
  });

  // ============================================================
  // Task Component Tests
  // ============================================================

  describe('Tasks', () => {
    const tasksPath = path.join(COMPONENTS_DIR, 'tasks');
    
    it('MainLoaderTask exists', () => {
      exists(path.join(tasksPath, 'MainLoaderTask.xml'));
      exists(path.join(tasksPath, 'MainLoaderTask.brs'));
    });

    it('MainLoaderTask extends Task', () => {
      const content = fs.readFileSync(path.join(tasksPath, 'MainLoaderTask.xml'), 'utf-8');
      includes(content, 'extends="Task"', 'MainLoaderTask should extend Task');
    });
  });

  // ============================================================
  // File Count Tests
  // ============================================================

  describe('Component Inventory', () => {
    it('has expected number of XML components', () => {
      greaterThan(xmlFiles.length, 10, 'Should have at least 10 component XML files');
    });

    it('has expected number of BRS files', () => {
      greaterThan(brsFiles.length, 10, 'Should have at least 10 component BRS files');
    });
  });
}
