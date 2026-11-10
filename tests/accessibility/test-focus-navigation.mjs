/**
 * Accessibility Tests: Focus Order, ARIA, and Navigation
 * 
 * Validates:
 * - Focus order compliance
 * - ARIA attribute presence
 * - Color contrast ratios
 * - Keyboard navigation paths
 * - Screen reader compatibility hints
 */

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT_DIR = path.resolve(__dirname, '..');
const COMPONENTS_DIR = path.join(ROOT_DIR, '..', 'components');

export default async function runTests({ describe, it, assertions }) {
  const { equal, truthy, falsy, isString, isNumber, 
           isArray, includes, match, greaterThan, lessThan } = assertions;

  // ============================================================
  // Helper: Parse XML for accessibility analysis
  // ============================================================

  function parseXmlNodes(xmlContent) {
    const nodes = [];
    
    // Extract all UI elements with focus-related attributes
    const elementRegex = /<(Label|Poster|Button|TextEdit|RowList|Grid|ContentNode)\s+([^>]*?)>/g;
    let match;
    while ((match = elementRegex.exec(xmlContent)) !== null) {
      nodes.push({
        tag: match[1],
        attrs: match[2],
      });
    }
    
    return nodes;
  }

  function hasAttribute(node, attr) {
    return node.attrs.includes(`${attr}=`);
  }

  // ============================================================
  // Color Contrast Tests
  // ============================================================

  function hexToRgb(hex) {
    const clean = hex.replace('0x', '').replace('#', '');
    return {
      r: parseInt(clean.substring(0, 2), 16),
      g: parseInt(clean.substring(2, 4), 16),
      b: parseInt(clean.substring(4, 6), 16),
    };
  }

  function luminance(rgb) {
    const [rs, gs, bs] = [rgb.r, rgb.g, rgb.b].map(c => {
      c /= 255;
      return c <= 0.03928 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4);
    });
    return 0.2126 * rs + 0.7152 * gs + 0.0722 * bs;
  }

  function contrastRatio(color1, color2) {
    const l1 = luminance(hexToRgb(color1));
    const l2 = luminance(hexToRgb(color2));
    const lighter = Math.max(l1, l2);
    const darker = Math.min(l1, l2);
    return (lighter + 0.05) / (darker + 0.05);
  }

  describe('Color Contrast', () => {
    const config = JSON.parse(
      fs.readFileSync(path.join(ROOT_DIR, '..', 'config', 'default.json'), 'utf-8')
    );
    const colors = config.branding.colors;

    it('text on background meets WCAG AA (4.5:1)', () => {
      const ratio = contrastRatio(colors.background, colors.textPrimary);
      greaterThan(ratio, 4.5, 
        `Text/background contrast is ${ratio.toFixed(2)}:1 (need 4.5:1)`);
    });

    it('secondary text on background meets WCAG AA', () => {
      const ratio = contrastRatio(colors.background, colors.textSecondary);
      greaterThan(ratio, 3.0, 
        `Secondary text/background contrast is ${ratio.toFixed(2)}:1 (need 3.0:1 for large text)`);
    });

    it('accent color on background is readable', () => {
      const ratio = contrastRatio(colors.background, colors.accent);
      greaterThan(ratio, 3.0, 
        `Accent/background contrast is ${ratio.toFixed(2)}:1`);
    });

    it('error color on background meets WCAG AA', () => {
      const ratio = contrastRatio(colors.background, colors.error);
      greaterThan(ratio, 3.0, 
        `Error/background contrast is ${ratio.toFixed(2)}:1`);
    });

    it('focus indicator on background is visible', () => {
      const ratio = contrastRatio(colors.background, colors.focus);
      greaterThan(ratio, 3.0, 
        `Focus/background contrast is ${ratio.toFixed(2)}:1`);
    });
  });

  // ============================================================
  // Focus Navigation Tests
  // ============================================================

  describe('Focus Navigation', () => {
    it('MainScene has focusable elements', () => {
      const mainSceneXml = fs.readFileSync(
        path.join(COMPONENTS_DIR, 'MainScene.xml'), 'utf-8'
      );
      
      // Should have at least one focusable element (retry button, etc.)
      truthy(mainSceneXml.includes('Button') || mainSceneXml.includes('focusBitmapUri'),
        'MainScene should have focusable elements');
    });

    it('error screen has focusable retry button', () => {
      const mainSceneXml = fs.readFileSync(
        path.join(COMPONENTS_DIR, 'MainScene.xml'), 'utf-8'
      );
      
      truthy(mainSceneXml.includes('retryButton') || mainSceneXml.includes('Button'),
        'Error screen should have a retry button');
    });

    it('search screen has focusable search field', () => {
      const searchXml = fs.readFileSync(
        path.join(COMPONENTS_DIR, 'SearchScreen.xml'), 'utf-8'
      );
      
      truthy(searchXml.includes('MiniKeyboard') || searchXml.includes('SearchField') || searchXml.includes('TextEdit') || searchXml.includes('Input'),
        'SearchScreen should have a focusable search field');
    });

    it('grid screen is focusable', () => {
      const gridPath = path.join(COMPONENTS_DIR, 'GridScreen');
      if (!fs.existsSync(gridPath)) return;
      
      const gridXml = fs.readFileSync(
        path.join(gridPath, 'GridScreen.xml'), 'utf-8'
      );
      
      truthy(gridXml.includes('RowList') || gridXml.includes('Grid'),
        'GridScreen should have a focusable list/grid');
    });
  });

  // ============================================================
  // Navigation Flow Tests
  // ============================================================

  describe('Navigation Flow', () => {
    it('MainScene.brs handles back key', () => {
      const mainSceneBrs = fs.readFileSync(
        path.join(COMPONENTS_DIR, 'MainScene.brs'), 'utf-8'
      );

      truthy(mainSceneBrs.includes('OnKeyEvent') || mainSceneBrs.includes('back'),
        'MainScene should handle back key navigation');
    });

    it('MainScene.brs handles search key', () => {
      const mainSceneBrs = fs.readFileSync(
        path.join(COMPONENTS_DIR, 'MainScene.brs'), 'utf-8'
      );

      truthy(mainSceneBrs.includes('search') && mainSceneBrs.includes('press'),
        'MainScene should handle search key');
    });

    it('SearchScreen.brs handles back to exit', () => {
      const searchBrs = fs.readFileSync(
        path.join(COMPONENTS_DIR, 'SearchScreen.brs'), 'utf-8'
      );

      truthy(searchBrs.includes('back') && searchBrs.includes('close'),
        'SearchScreen should allow back to close');
    });

    it('GridScreen.brs handles exit dialog navigation', () => {
      const gridBrs = fs.readFileSync(
        path.join(COMPONENTS_DIR, 'GridScreen', 'GridScreen.brs'), 'utf-8'
      );

      truthy(gridBrs.includes('ShowExitDialog'),
        'GridScreen should have ShowExitDialog function');
      truthy(gridBrs.includes('HideExitDialog'),
        'GridScreen should have HideExitDialog function');
      truthy(gridBrs.includes('ExitApp'),
        'GridScreen should have ExitApp function');
      truthy(gridBrs.includes('dialogVisible'),
        'GridScreen should track dialog visibility state');
    });

    it('GridScreen exit dialog OK handler triggers app exit', () => {
      const gridBrs = fs.readFileSync(
        path.join(COMPONENTS_DIR, 'GridScreen', 'GridScreen.brs'), 'utf-8'
      );

      // Verify OnExitRequested handler exists and calls CloseChannel/ExitApp
      truthy(gridBrs.includes('OnExitRequested'),
        'GridScreen should have OnExitRequested handler');
      // Verify exit mechanism exists
      truthy(gridBrs.includes('CloseChannel') || gridBrs.includes('ExitApp'),
        'GridScreen should have a mechanism to close the channel');
    });

     it('GridScreen observes exitRequested on exitButton', () => {
      const gridBrs = fs.readFileSync(
        path.join(COMPONENTS_DIR, 'GridScreen', 'GridScreen.brs'), 'utf-8'
      );

      // The exitButton fires "exitRequested" when OK/SELECT is pressed
      truthy(gridBrs.includes('exitRequested') && gridBrs.includes('ObserveField'),
        'GridScreen should observe the exitRequested field on exitButton');
    });

    it('GridScreen clears rowList focus when showing exit dialog', () => {
      const gridBrs = fs.readFileSync(
        path.join(COMPONENTS_DIR, 'GridScreen', 'GridScreen.brs'), 'utf-8'
      );

      // Verify that ShowExitDialog clears rowList focus to prevent
      // the rowList from consuming key events while the dialog is visible
      truthy(gridBrs.includes('SetFocus(false)'),
        'ShowExitDialog should clear rowList focus to prevent key event swallowing');
    });

    it('GridScreen exit button has visible text', () => {
      const gridXml = fs.readFileSync(
        path.join(COMPONENTS_DIR, 'GridScreen', 'GridScreen.xml'), 'utf-8'
      );

      // Verify the exit button text label exists and has content
      const textMatch = gridXml.match(/id="exitButtonText"[\s\S]*?text="([^"]*)"/);
      truthy(textMatch && textMatch[1].length > 0,
        'exitButtonText should have non-empty text content');
    });
  });

  // ============================================================
  // Text Readability Tests
  // ============================================================

  describe('Text Readability', () => {
    it('uses system fonts for readability', () => {
      const config = JSON.parse(
        fs.readFileSync(path.join(ROOT_DIR, '..', 'config', 'default.json'), 'utf-8')
      );
      
      const validFonts = [
        'font:MediumSystemFont', 'font:MediumBoldSystemFont',
        'font:SmallSystemFont', 'font:SmallBoldSystemFont',
        'font:LargeSystemFont', 'font:LargeBoldSystemFont',
        'font:ExtraLargeSystemFont',
        'font:BoldSystemFont', 'font:ExtraBoldSystemFont',
      ];
      
      for (const [key, value] of Object.entries(config.branding.fonts)) {
        includes(validFonts, value, 
          `Font "${key}" should use a system font`);
      }
    });

    it('error messages are readable', () => {
      const mainSceneXml = fs.readFileSync(
        path.join(COMPONENTS_DIR, 'MainScene.xml'), 'utf-8'
      );
      
      // Error screen should use a readable font
      truthy(mainSceneXml.includes('font:MediumSystemFont') || 
             mainSceneXml.includes('font:SmallSystemFont') ||
             mainSceneXml.includes('font:BoldSystemFont'),
        'Error messages should use readable system fonts');
    });

    it('text colors have sufficient contrast', () => {
      const config = JSON.parse(
        fs.readFileSync(path.join(ROOT_DIR, '..', 'config', 'default.json'), 'utf-8')
      );
      
      // Check card style text colors
      if (config.cardStyle) {
        const titleRatio = contrastRatio(
          config.branding.colors.background,
          config.cardStyle.titleColor || config.branding.colors.textPrimary
        );
        greaterThan(titleRatio, 3.0, 'Card title should have readable contrast');
      }
    });
  });

  // ============================================================
  // Screen Reader Compatibility
  // ============================================================

  describe('Screen Reader Hints', () => {
    it('MainScene has descriptive labels', () => {
      const mainSceneXml = fs.readFileSync(
        path.join(COMPONENTS_DIR, 'MainScene.xml'), 'utf-8'
      );
      
      // Welcome screen should have title
      truthy(mainSceneXml.includes('welcomeTitle'),
        'MainScene should have welcome title');
    });

    it('error screen has descriptive message', () => {
      const mainSceneXml = fs.readFileSync(
        path.join(COMPONENTS_DIR, 'MainScene.xml'), 'utf-8'
      );
      
      truthy(mainSceneXml.includes('errorMessage'),
        'Error screen should have error message label');
    });

    it('loading indicator has status text', () => {
      const mainSceneXml = fs.readFileSync(
        path.join(COMPONENTS_DIR, 'MainScene.xml'), 'utf-8'
      );
      
      truthy(mainSceneXml.includes('loadingText') || mainSceneXml.includes('Loading'),
        'Loading indicator should have descriptive text');
    });
  });
}
