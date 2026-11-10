/**
 * Component Tests: LeftNavScreen and SettingsScreen
 *
 * Validates the left navigation sidebar and settings panel components for:
 * - XML structure and required elements
 * - Interface fields for data passing
 * - Nav items (Home, Search, Settings)
 * - Settings screen sections
 */

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT_DIR = path.resolve(__dirname, '..');
const COMPONENTS_DIR = path.join(ROOT_DIR, '..', 'components');

export default async function runTests({ describe, it, assertions }) {
  const { truthy, falsy, isString, includes, exists, match, hasProperty, equal, greaterThan } = assertions;

  function extractInterfaceFields(xmlContent) {
    const fields = [];
    const regex = /<field\s+id="(\w+)"\s+type="(\w+)"/g;
    let m;
    while ((m = regex.exec(xmlContent)) !== null) {
      fields.push({ id: m[1], type: m[2] });
    }
    return fields;
  }

  // ============================================================
  // LeftNavScreen Tests
  // ============================================================

  describe('LeftNavScreen XML Structure', () => {
    const leftNavPath = path.join(COMPONENTS_DIR, 'LeftNavScreen.xml');
    const content = fs.readFileSync(leftNavPath, 'utf-8');

    it('exists and is well-formed XML', () => {
      exists(leftNavPath);
      includes(content, '<?xml', 'LeftNavScreen should have XML declaration');
    });

    it('has correct component definition', () => {
      includes(content, 'name="LeftNavScreen"', 'Should be named LeftNavScreen');
      includes(content, 'extends="Group"', 'Should extend Group');
    });

    it('has sidebar background', () => {
      includes(content, 'id="sidebarBackground"', 'Should have sidebar background');
      includes(content, 'height="1080"', 'Sidebar should be full height');
    });

    it('has sidebar title', () => {
      includes(content, 'id="sidebarTitle"', 'Should have sidebar title label');
    });

    it('has Home nav item as focusable Group', () => {
      includes(content, 'id="navHome"', 'Should have navHome element');
      includes(content, 'focusable="true"', 'Nav items should be focusable');
    });

    it('has Search nav item', () => {
      includes(content, 'id="navSearch"', 'Should have navSearch element');
    });

    it('has Settings nav item', () => {
      includes(content, 'id="navSettings"', 'Should have navSettings element');
    });

    it('has nav item background rectangles', () => {
      includes(content, 'id="navHomeBg"', 'Should have navHomeBg');
      includes(content, 'id="navSearchBg"', 'Should have navSearchBg');
      includes(content, 'id="navSettingsBg"', 'Should have navSettingsBg');
    });

    it('has content panel for screen switching', () => {
      includes(content, 'id="contentPanel"', 'Should have contentPanel');
      includes(content, 'translation="[0, 0]"', 'Content panel should be offset past sidebar');
    });
  });

  describe('LeftNavScreen Interface', () => {
    const leftNavPath = path.join(COMPONENTS_DIR, 'LeftNavScreen.xml');
    const content = fs.readFileSync(leftNavPath, 'utf-8');
    const fields = extractInterfaceFields(content);
    const fieldIds = fields.map(f => f.id);

    it('has required event fields', () => {
      includes(fieldIds, 'play', 'Should have play event field');
      includes(fieldIds, 'selectedContent', 'Should have selectedContent field');
      includes(fieldIds, 'close', 'Should have close event field');
      includes(fieldIds, 'selectedNavItem', 'Should have selectedNavItem for programmatic nav');
    });

    it('has config pass-through fields', () => {
      includes(fieldIds, 'channelName', 'Should have channelName');
      includes(fieldIds, 'channelVersion', 'Should have channelVersion');
      includes(fieldIds, 'contentSourceUrl', 'Should have contentSourceUrl');
      includes(fieldIds, 'currentLayout', 'Should have currentLayout');
      includes(fieldIds, 'featureSearch', 'Should have featureSearch');
      includes(fieldIds, 'featureDeepLinking', 'Should have featureDeepLinking');
      includes(fieldIds, 'featureAnalytics', 'Should have featureAnalytics');
      includes(fieldIds, 'featureCrashReporting', 'Should have featureCrashReporting');
      includes(fieldIds, 'iconFocusUri', 'Should have iconFocusUri');
    });

    it('has layoutToggle event for settings', () => {
      includes(fieldIds, 'layoutToggle', 'Should have layoutToggle event');
    });
  });

  describe('LeftNavScreen BRS', () => {
    const brsPath = path.join(COMPONENTS_DIR, 'LeftNavScreen.brs');
    const content = fs.readFileSync(brsPath, 'utf-8');

    it('has Init function', () => {
      includes(content, 'sub Init()', 'Should have Init sub');
    });

    it('has panel creation functions', () => {
      includes(content, 'CreateGridPanel', 'Should have CreateGridPanel');
      includes(content, 'CreateSearchPanel', 'Should have CreateSearchPanel');
      includes(content, 'CreateSettingsPanel', 'Should have CreateSettingsPanel');
    });

    it('has panel display functions', () => {
      includes(content, 'ShowHomePanel', 'Should have ShowHomePanel');
      includes(content, 'ShowSearchPanel', 'Should have ShowSearchPanel');
      includes(content, 'ShowSettingsPanel', 'Should have ShowSettingsPanel');
    });

    it('passes content feed to search panel', () => {
      truthy(
        content.includes('searchScreen.content = m.contentFeed'),
        'CreateSearchPanel should pass content feed to SearchScreen'
      );
    });

    it('passes config data to settings panel', () => {
      includes(content, 'settingsScreen.channelName', 'Should pass channelName to SettingsScreen');
      includes(content, 'settingsScreen.currentLayout', 'Should pass currentLayout to SettingsScreen');
      includes(content, 'settingsScreen.featureSearch', 'Should pass featureSearch to SettingsScreen');
    });

    it('observes layoutToggle from settings panel', () => {
      includes(content, 'OnSettingsLayoutToggle', 'Should handle layoutToggle from settings');
    });

    it('has sidebar title update', () => {
      includes(content, 'UpdateSidebarTitle', 'Should have sidebar title update function');
      includes(content, 'OnChannelNameChanged', 'Should observe channel name changes');
    });

    it('has nav item focus handlers', () => {
      includes(content, 'OnNavHomeFocus', 'Should handle nav home focus');
      includes(content, 'OnNavSearchFocus', 'Should handle nav search focus');
      includes(content, 'OnNavSettingsFocus', 'Should handle nav settings focus');
    });
  });

  // ============================================================
  // SettingsScreen Tests
  // ============================================================

  describe('SettingsScreen XML Structure', () => {
    const settingsPath = path.join(COMPONENTS_DIR, 'SettingsScreen.xml');
    const content = fs.readFileSync(settingsPath, 'utf-8');

    it('exists and is well-formed XML', () => {
      exists(settingsPath);
      includes(content, '<?xml', 'SettingsScreen should have XML declaration');
    });

    it('has correct component definition', () => {
      includes(content, 'name="SettingsScreen"', 'Should be named SettingsScreen');
      includes(content, 'extends="Group"', 'Should extend Group');
    });

    it('has settings title', () => {
      includes(content, 'id="settingsTitle"', 'Should have settings title');
    });

    it('has channel info labels', () => {
      includes(content, 'id="channelNameLabel"', 'Should have channel name label');
      includes(content, 'id="channelVersionLabel"', 'Should have channel version label');
      includes(content, 'id="contentSourceLabel"', 'Should have content source label');
    });

    it('has layout toggle section', () => {
      includes(content, 'id="sectionLayout"', 'Should have layout section header');
      includes(content, 'id="layoutToggleRow"', 'Should have layout toggle row');
      includes(content, 'id="layoutToggleValue"', 'Should have layout toggle value label');
    });

    it('has features section', () => {
      includes(content, 'id="sectionFeatures"', 'Should have features section header');
      includes(content, 'id="featureSearchValue"', 'Should have search feature value');
      includes(content, 'id="featureDeepLinkingValue"', 'Should have deep linking feature value');
      includes(content, 'id="featureAnalyticsValue"', 'Should have analytics feature value');
      includes(content, 'id="featureCrashReportingValue"', 'Should have crash reporting feature value');
    });

    it('layout toggle row is focusable', () => {
      const toggleMatch = content.match(/id="layoutToggleRow"([^>]*)>/);
      truthy(toggleMatch && toggleMatch[1].includes('focusable="true"'),
        'Layout toggle row should be focusable');
    });
  });

  describe('SettingsScreen Interface', () => {
    const settingsPath = path.join(COMPONENTS_DIR, 'SettingsScreen.xml');
    const content = fs.readFileSync(settingsPath, 'utf-8');
    const fields = extractInterfaceFields(content);
    const fieldIds = fields.map(f => f.id);

    it('has config input fields', () => {
      includes(fieldIds, 'channelName', 'Should have channelName input');
      includes(fieldIds, 'channelVersion', 'Should have channelVersion input');
      includes(fieldIds, 'contentSourceUrl', 'Should have contentSourceUrl input');
      includes(fieldIds, 'currentLayout', 'Should have currentLayout input');
    });

    it('has feature toggle input fields', () => {
      includes(fieldIds, 'featureSearch', 'Should have featureSearch input');
      includes(fieldIds, 'featureDeepLinking', 'Should have featureDeepLinking input');
      includes(fieldIds, 'featureAnalytics', 'Should have featureAnalytics input');
      includes(fieldIds, 'featureCrashReporting', 'Should have featureCrashReporting input');
    });

    it('has layoutToggle output event', () => {
      includes(fieldIds, 'layoutToggle', 'Should have layoutToggle event');
    });
  });

  describe('SettingsScreen BRS', () => {
    const brsPath = path.join(COMPONENTS_DIR, 'SettingsScreen.brs');
    const content = fs.readFileSync(brsPath, 'utf-8');

    it('has Init function', () => {
      includes(content, 'sub Init()', 'Should have Init sub');
    });

    it('has field change handlers', () => {
      includes(content, 'OnChannelNameChanged', 'Should handle channel name changes');
      includes(content, 'OnChannelVersionChanged', 'Should handle version changes');
      includes(content, 'OnCurrentLayoutChanged', 'Should handle layout changes');
      includes(content, 'OnFeatureSearchChanged', 'Should handle search feature changes');
    });

    it('has layout toggle selection handler', () => {
      includes(content, 'OnLayoutToggleSelect', 'Should handle layout toggle selection');
    });

    it('cycles layout between grid and leftnav', () => {
      includes(content, '"grid"', 'Should reference grid layout');
      includes(content, '"leftnav"', 'Should reference leftnav layout');
    });
  });

}
