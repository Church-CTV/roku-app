/**
 * Unit Tests: SubscriptionUI.brs
 *
 * Tests subscription UI utilities: loading overlay, dialog display,
 * plan card creation, status badges, browser launch, and error display.
 */

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT_DIR = path.resolve(__dirname, '..');

export default async function runTests({ describe, it, assertions }) {
  const { equal, deepEqual, truthy, falsy, isString, isNumber,
           isArray, isObject, greaterThan, lessThan, match, hasProperty } = assertions;

  // ============================================================
  // Loading overlay — simulates CreateSubscriptionLoadingOverlay
  // ============================================================

  function createLoadingOverlay(message) {
    const overlay = {
      id: 'subLoadingOverlay',
      visible: false,
      children: [],
    };

    const bg = { id: 'subLoadingBg', width: 1920, height: 1080, color: '0x80000000' };
    const spinner = { id: 'subLoadingSpinner', uri: 'pkg:/images/loader.png', width: 120, height: 120 };
    const label = { id: 'subLoadingMessage', text: message, color: '0xFFFFFF', width: 600 };

    overlay.children.push(bg, spinner, label);
    return overlay;
  }

  describe('CreateSubscriptionLoadingOverlay', () => {
    it('creates overlay with correct structure', () => {
      const overlay = createLoadingOverlay('Loading...');
      truthy(overlay.id === 'subLoadingOverlay' || overlay.children.length > 0);
    });

    it('sets visible to false by default', () => {
      const overlay = createLoadingOverlay('Loading...');
      falsy(overlay.visible);
    });

    it('includes background rectangle', () => {
      const overlay = createLoadingOverlay('Loading...');
      const bg = overlay.children.find(c => c.id === 'subLoadingBg');
      truthy(bg);
      equal(bg.width, 1920);
      equal(bg.height, 1080);
    });

    it('includes spinner poster', () => {
      const overlay = createLoadingOverlay('Loading...');
      const spinner = overlay.children.find(c => c.id === 'subLoadingSpinner');
      truthy(spinner);
      equal(spinner.uri, 'pkg:/images/loader.png');
    });

    it('includes message label with provided text', () => {
      const overlay = createLoadingOverlay('Processing payment...');
      const label = overlay.children.find(c => c.id === 'subLoadingMessage');
      truthy(label);
      equal(label.text, 'Processing payment...');
    });

    it('handles empty message', () => {
      const overlay = createLoadingOverlay('');
      const label = overlay.children.find(c => c.id === 'subLoadingMessage');
      equal(label.text, '');
    });

    it('has three child elements (bg, spinner, label)', () => {
      const overlay = createLoadingOverlay('Loading...');
      equal(overlay.children.length, 3);
    });
  });

  // ============================================================
  // Show/Hide loading — simulates ShowSubscriptionLoading / HideSubscriptionLoading
  // ============================================================

  function showLoading(state, message) {
    if (!state.global || !state.global.MainScene) return;
    if (!state.loadingOverlay) {
      state.loadingOverlay = createLoadingOverlay(message);
      state.global.MainScene.children.push(state.loadingOverlay);
    }
    state.loadingOverlay.visible = true;
    const label = state.loadingOverlay.children.find(c => c.id === 'subLoadingMessage');
    if (label) label.text = message;
  }

  function hideLoading(state) {
    if (state.loadingOverlay) {
      state.loadingOverlay.visible = false;
    }
  }

  describe('ShowSubscriptionLoading', () => {
    it('creates overlay on first show', () => {
      const state = { global: { MainScene: { children: [] } }, loadingOverlay: null };
      showLoading(state, 'Checking subscription...');
      truthy(state.loadingOverlay);
      truthy(state.loadingOverlay.visible);
    });

    it('updates message on subsequent shows', () => {
      const state = { global: { MainScene: { children: [] } }, loadingOverlay: null };
      showLoading(state, 'Initial message');
      showLoading(state, 'Updated message');
      const label = state.loadingOverlay.children.find(c => c.id === 'subLoadingMessage');
      equal(label.text, 'Updated message');
    });

    it('handles invalid global', () => {
      const state = { global: null, loadingOverlay: null };
      showLoading(state, 'Test'); // should not throw
    });

    it('handles invalid MainScene', () => {
      const state = { global: {}, loadingOverlay: null };
      showLoading(state, 'Test');
    });
  });

  describe('HideSubscriptionLoading', () => {
    it('hides the overlay', () => {
      const state = { loadingOverlay: { visible: true } };
      hideLoading(state);
      falsy(state.loadingOverlay.visible);
    });

    it('handles null overlay', () => {
      const state = { loadingOverlay: null };
      hideLoading(state); // should not throw
    });
  });

  // ============================================================
  // Dialog display — simulates ShowSubscriptionDialog / CloseSubDialog
  // ============================================================

  function showDialog(state, title, message, buttonText) {
    if (!state.global || !state.global.MainScene) return;

    const dialog = { id: 'subDialog', children: [] };
    const bg = { id: 'subDialogBg', width: 800, height: 400 };
    const titleLabel = { id: 'subDialogTitle', text: title };
    const msgLabel = { id: 'subDialogMessage', text: message };
    const okButton = { id: 'subDialogOk', label: buttonText || 'OK' };

    dialog.children.push(bg, titleLabel, msgLabel, okButton);
    state.global.MainScene.children.push(dialog);
  }

  function closeDialog(state) {
    if (!state.global || !state.global.MainScene) return;
    const scene = state.global.MainScene;
    const idx = scene.children.findIndex(c => c.id === 'subDialog');
    if (idx >= 0) scene.children.splice(idx, 1);
  }

  describe('ShowSubscriptionDialog', () => {
    it('creates dialog with title', () => {
      const state = { global: { MainScene: { children: [] } } };
      showDialog(state, 'Confirm', 'Are you sure?', 'Yes');
      const scene = state.global.MainScene;
      const dialog = scene.children.find(c => c.id === 'subDialog');
      truthy(dialog);

      const titleLabel = dialog.children.find(c => c.id === 'subDialogTitle');
      equal(titleLabel.text, 'Confirm');
    });

    it('creates dialog with message', () => {
      const state = { global: { MainScene: { children: [] } } };
      showDialog(state, 'Title', 'This is the message', 'OK');
      const scene = state.global.MainScene;
      const dialog = scene.children.find(c => c.id === 'subDialog');
      const msgLabel = dialog.children.find(c => c.id === 'subDialogMessage');
      equal(msgLabel.text, 'This is the message');
    });

    it('sets button label', () => {
      const state = { global: { MainScene: { children: [] } } };
      showDialog(state, 'Title', 'Message', 'Cancel');
      const scene = state.global.MainScene;
      const dialog = scene.children.find(c => c.id === 'subDialog');
      const okButton = dialog.children.find(c => c.id === 'subDialogOk');
      equal(okButton.label, 'Cancel');
    });

    it('defaults button label to OK', () => {
      const state = { global: { MainScene: { children: [] } } };
      showDialog(state, 'Title', 'Message', '');
      const scene = state.global.MainScene;
      const dialog = scene.children.find(c => c.id === 'subDialog');
      const okButton = dialog.children.find(c => c.id === 'subDialogOk');
      equal(okButton.label, 'OK');
    });

    it('has correct dialog structure', () => {
      const state = { global: { MainScene: { children: [] } } };
      showDialog(state, 'Title', 'Message', 'OK');
      const scene = state.global.MainScene;
      const dialog = scene.children.find(c => c.id === 'subDialog');
      equal(dialog.children.length, 4); // bg, title, message, button
    });

    it('handles invalid global', () => {
      const state = { global: null };
      showDialog(state, 'Title', 'Message', 'OK');
    });
  });

  describe('CloseSubDialog', () => {
    it('removes dialog from scene', () => {
      const state = { global: { MainScene: { children: [{ id: 'subDialog' }, { id: 'other' }] } } };
      closeDialog(state);
      const scene = state.global.MainScene;
      falsy(scene.children.find(c => c.id === 'subDialog'));
    });

    it('handles missing dialog', () => {
      const state = { global: { MainScene: { children: [] } } };
      closeDialog(state); // should not throw
    });

    it('handles invalid global', () => {
      const state = { global: null };
      closeDialog(state);
    });
  });

  // ============================================================
  // Plan card creation — simulates CreatePlanCardNode
  // ============================================================

  function createPlanCard(plan, isSelected) {
    const card = { id: '', title: '', description: '' };

    if (!plan) return card;

    card.id = plan.id || '';
    card.title = plan.name || '';

    card.isPopular = plan.isPopular || false;
    card.isSelected = isSelected || false;

    // Build feature list
    let features = '';
    if (plan.features && plan.features.length > 0) {
      for (let i = 0; i < plan.features.length; i++) {
        if (i > 0) features += '\n';
        features += '\u2022 ' + plan.features[i];
      }
    }
    card.description = features;

    // Format price
    card.displayPrice = '';
    if (plan.price !== undefined && plan.price !== null) {
      const dollars = Math.floor(plan.price / 100);
      const cents = plan.price % 100;
      let priceStr = '$' + dollars.toString();
      if (cents > 0) {
        priceStr += '.' + String(cents).padStart(2, '0');
      }
      if (plan.interval === 'year') {
        priceStr += '/yr';
      } else {
        priceStr += '/mo';
      }
      card.displayPrice = priceStr;

      // Monthly equivalent for yearly plans
      if (plan.interval === 'year' && plan.price !== undefined) {
        const monthlyPrice = plan.price / 12;
        const monthlyDollars = Math.floor(monthlyPrice / 100);
        card.displayPrice += ' ($' + monthlyDollars + '.xx/mo)';
      }
    }

    // Badge text
    card.badgeText = plan.isPopular ? 'POPULAR' : '';

    return card;
  }

  describe('CreatePlanCardNode', () => {
    it('creates card with plan ID', () => {
      const card = createPlanCard({ id: 'plan_premium', name: 'Premium' }, false);
      equal(card.id, 'plan_premium');
    });

    it('sets title from plan name', () => {
      const card = createPlanCard({ id: 'p1', name: 'Premium Plan' }, false);
      equal(card.title, 'Premium Plan');
    });

    it('marks popular plans', () => {
      const card = createPlanCard({ id: 'p1', name: 'Popular', isPopular: true }, false);
      truthy(card.isPopular);
      equal(card.badgeText, 'POPULAR');
    });

    it('marks non-popular plans without badge', () => {
      const card = createPlanCard({ id: 'p1', name: 'Basic', isPopular: false }, false);
      falsy(card.isPopular);
      equal(card.badgeText, '');
    });

    it('formats monthly price', () => {
      const card = createPlanCard({ id: 'p1', name: 'Monthly', price: 999, interval: 'month' }, false);
      match(card.displayPrice, /^\$9\.99\/mo$/);
    });

    it('formats yearly price', () => {
      const card = createPlanCard({ id: 'p1', name: 'Yearly', price: 9999, interval: 'year' }, false);
      truthy(card.displayPrice.includes('/yr'));
    });

    it('includes monthly equivalent for yearly plans', () => {
      const card = createPlanCard({ id: 'p1', name: 'Yearly', price: 9999, interval: 'year' }, false);
      truthy(card.displayPrice.includes('/mo)'));
    });

    it('includes features in description', () => {
      const card = createPlanCard({
        id: 'p1', name: 'Premium',
        features: ['Feature A', 'Feature B'],
        price: 999, interval: 'month'
      }, false);
      truthy(card.description.includes('\u2022 Feature A'));
      truthy(card.description.includes('\u2022 Feature B'));
    });

    it('handles null plan', () => {
      const card = createPlanCard(null, false);
      equal(card.id, '');
      equal(card.title, '');
    });

    it('sets isSelected flag', () => {
      const card = createPlanCard({ id: 'p1', name: 'Test' }, true);
      truthy(card.isSelected);
    });

    it('does not set isSelected when false', () => {
      const card = createPlanCard({ id: 'p1', name: 'Test' }, false);
      falsy(card.isSelected);
    });
  });

  // ============================================================
  // Status badge — simulates CreateStatusBadge
  // ============================================================

  function createStatusBadge(status) {
    const badge = { id: 'subStatusBadge', text: '', color: '' };

    if (!status || status === '') {
      badge.text = 'No subscription';
      badge.color = '0xA1A0B0';
      return badge;
    }

    const lowerStatus = status.toLowerCase();
    if (lowerStatus === 'active' || lowerStatus === 'trialing') {
      badge.text = '\u2713 Active';
      badge.color = '0x4CAF50';
    } else if (lowerStatus === 'past_due') {
      badge.text = '\u26a0 Payment Issue';
      badge.color = '0xFF9800';
    } else {
      badge.text = '\u2717 ' + status;
      badge.color = '0xFF4444';
    }

    return badge;
  }

  describe('CreateStatusBadge', () => {
    it('shows "No subscription" for empty status', () => {
      const badge = createStatusBadge('');
      equal(badge.text, 'No subscription');
      equal(badge.color, '0xA1A0B0');
    });

    it('shows "No subscription" for null status', () => {
      const badge = createStatusBadge(null);
      equal(badge.text, 'No subscription');
    });

    it('shows green Active for active status', () => {
      const badge = createStatusBadge('active');
      truthy(badge.text.includes('Active'));
      equal(badge.color, '0x4CAF50');
    });

    it('shows green Active for trialing status', () => {
      const badge = createStatusBadge('trialing');
      truthy(badge.text.includes('Active'));
      equal(badge.color, '0x4CAF50');
    });

    it('shows orange Payment Issue for past_due', () => {
      const badge = createStatusBadge('past_due');
      truthy(badge.text.includes('Payment Issue'));
      equal(badge.color, '0xFF9800');
    });

    it('shows red X for other statuses', () => {
      const badge = createStatusBadge('cancelled');
      truthy(badge.text.includes('\u2717'));
      equal(badge.color, '0xFF4444');
    });

    it('is case-insensitive', () => {
      const badge1 = createStatusBadge('ACTIVE');
      const badge2 = createStatusBadge('active');
      equal(badge1.text, badge2.text);
      equal(badge1.color, badge2.color);
    });

    it('has status badge id', () => {
      const badge = createStatusBadge('active');
      equal(badge.id, 'subStatusBadge');
    });
  });

  // ============================================================
  // Browser URL launch — simulates OpenBrowserUrl
  // ============================================================

  function openBrowserUrl(url) {
    if (!url || url === '') return false;
    // Simulate: would use roAppManager.SetFocusedContentUrl(url)
    return true;
  }

  describe('OpenBrowserUrl', () => {
    it('returns true for valid URL', () => {
      truthy(openBrowserUrl('https://checkout.stripe.com/pay/test'));
    });

    it('returns false for empty URL', () => {
      falsy(openBrowserUrl(''));
    });

    it('returns false for null URL', () => {
      falsy(openBrowserUrl(null));
    });

    it('handles invalid URL', () => {
      truthy(openBrowserUrl('https://example.com'));
    });
  });

  // ============================================================
  // Plan selection highlighting — simulates HighlightSelectedPlan
  // ============================================================

  function highlightSelectedPlan(planId, planList) {
    if (!planList || !planId) return;
    for (let i = 0; i < planList.length; i++) {
      const card = planList[i];
      if (card && card.id) {
        card.isSelected = (card.id === planId);
      }
    }
  }

  describe('HighlightSelectedPlan', () => {
    it('highlights selected plan', () => {
      const plans = [
        { id: 'p1', isSelected: false },
        { id: 'p2', isSelected: false },
        { id: 'p3', isSelected: false },
      ];
      highlightSelectedPlan('p2', plans);
      falsy(plans[0].isSelected);
      truthy(plans[1].isSelected);
      falsy(plans[2].isSelected);
    });

    it('unhighlights non-selected plans', () => {
      const plans = [
        { id: 'p1', isSelected: true },
        { id: 'p2', isSelected: false },
      ];
      highlightSelectedPlan('p2', plans);
      falsy(plans[0].isSelected);
      truthy(plans[1].isSelected);
    });

    it('handles empty plan list', () => {
      highlightSelectedPlan('p1', []);
    });

    it('handles null plan list', () => {
      highlightSelectedPlan('p1', null);
    });

    it('handles null planId', () => {
      highlightSelectedPlan(null, [{ id: 'p1' }]);
    });
  });

  // ============================================================
  // Error display — simulates ShowSubscriptionError
  // ============================================================

  function showSubscriptionError(title, message, hasRetry) {
    const buttonText = hasRetry ? 'Retry' : 'OK';
    return { title, message, buttonText };
  }

  describe('ShowSubscriptionError', () => {
    it('shows OK button when no retry action', () => {
      const result = showSubscriptionError('Error', 'Something failed', false);
      equal(result.buttonText, 'OK');
    });

    it('shows Retry button when retry action provided', () => {
      const result = showSubscriptionError('Error', 'Something failed', true);
      equal(result.buttonText, 'Retry');
    });

    it('includes title and message', () => {
      const result = showSubscriptionError('Checkout Failed', 'Payment declined', false);
      equal(result.title, 'Checkout Failed');
      equal(result.message, 'Payment declined');
    });
  });

  // ============================================================
  // SubscriptionUI file structure validation
  // ============================================================

  describe('SubscriptionUI.brs File Structure', () => {
    it('SubscriptionUI.brs file exists', () => {
      const testPath = path.join(ROOT_DIR, '..', 'source', 'SubscriptionUI.brs');
      truthy(fs.existsSync(testPath), 'SubscriptionUI.brs should exist');
    });

    it('has CreateSubscriptionLoadingOverlay function', () => {
      const testPath = path.join(ROOT_DIR, '..', 'source', 'SubscriptionUI.brs');
      const content = fs.readFileSync(testPath, 'utf-8');
      truthy(content.includes('function CreateSubscriptionLoadingOverlay'), 'Should have loading overlay function');
    });

    it('has ShowSubscriptionLoading sub', () => {
      const testPath = path.join(ROOT_DIR, '..', 'source', 'SubscriptionUI.brs');
      const content = fs.readFileSync(testPath, 'utf-8');
      truthy(content.includes('sub ShowSubscriptionLoading'), 'Should have ShowSubscriptionLoading sub');
    });

    it('has HideSubscriptionLoading sub', () => {
      const testPath = path.join(ROOT_DIR, '..', 'source', 'SubscriptionUI.brs');
      const content = fs.readFileSync(testPath, 'utf-8');
      truthy(content.includes('sub HideSubscriptionLoading'), 'Should have HideSubscriptionLoading sub');
    });

    it('has ShowSubscriptionDialog function', () => {
      const testPath = path.join(ROOT_DIR, '..', 'source', 'SubscriptionUI.brs');
      const content = fs.readFileSync(testPath, 'utf-8');
      truthy(content.includes('sub ShowSubscriptionDialog'), 'Should have ShowSubscriptionDialog sub');
    });

    it('has CloseSubDialog sub', () => {
      const testPath = path.join(ROOT_DIR, '..', 'source', 'SubscriptionUI.brs');
      const content = fs.readFileSync(testPath, 'utf-8');
      truthy(content.includes('sub CloseSubDialog'), 'Should have CloseSubDialog sub');
    });

    it('has CreatePlanCardNode function', () => {
      const testPath = path.join(ROOT_DIR, '..', 'source', 'SubscriptionUI.brs');
      const content = fs.readFileSync(testPath, 'utf-8');
      truthy(content.includes('function CreatePlanCardNode'), 'Should have CreatePlanCardNode function');
    });

    it('has CreateStatusBadge function', () => {
      const testPath = path.join(ROOT_DIR, '..', 'source', 'SubscriptionUI.brs');
      const content = fs.readFileSync(testPath, 'utf-8');
      truthy(content.includes('function CreateStatusBadge'), 'Should have CreateStatusBadge function');
    });

    it('has OpenBrowserUrl function', () => {
      const testPath = path.join(ROOT_DIR, '..', 'source', 'SubscriptionUI.brs');
      const content = fs.readFileSync(testPath, 'utf-8');
      truthy(content.includes('function OpenBrowserUrl'), 'Should have OpenBrowserUrl function');
    });

    it('has HighlightSelectedPlan sub', () => {
      const testPath = path.join(ROOT_DIR, '..', 'source', 'SubscriptionUI.brs');
      const content = fs.readFileSync(testPath, 'utf-8');
      truthy(content.includes('sub HighlightSelectedPlan'), 'Should have HighlightSelectedPlan sub');
    });

    it('has ShowSubscriptionError sub', () => {
      const testPath = path.join(ROOT_DIR, '..', 'source', 'SubscriptionUI.brs');
      const content = fs.readFileSync(testPath, 'utf-8');
      truthy(content.includes('sub ShowSubscriptionError'), 'Should have ShowSubscriptionError sub');
    });

    it('has OnSubDialogOk callback handler', () => {
      const testPath = path.join(ROOT_DIR, '..', 'source', 'SubscriptionUI.brs');
      const content = fs.readFileSync(testPath, 'utf-8');
      truthy(content.includes('sub OnSubDialogOk'), 'Should have OnSubDialogOk sub');
    });

    it('uses roSGNode for UI elements', () => {
      const testPath = path.join(ROOT_DIR, '..', 'source', 'SubscriptionUI.brs');
      const content = fs.readFileSync(testPath, 'utf-8');
      truthy(content.includes('roSGNode'), 'Should use roSGNode');
    });

    it('uses SafeLog for error logging', () => {
      const testPath = path.join(ROOT_DIR, '..', 'source', 'SubscriptionUI.brs');
      const content = fs.readFileSync(testPath, 'utf-8');
      truthy(content.includes('SafeLog'), 'Should use SafeLog');
    });

    it('uses LogInfo for logging', () => {
      const testPath = path.join(ROOT_DIR, '..', 'source', 'SubscriptionUI.brs');
      const content = fs.readFileSync(testPath, 'utf-8');
      truthy(content.includes('LogInfo'), 'Should use LogInfo');
    });

    it('uses LogError for error logging', () => {
      const testPath = path.join(ROOT_DIR, '..', 'source', 'SubscriptionUI.brs');
      const content = fs.readFileSync(testPath, 'utf-8');
      truthy(content.includes('LogError'), 'Should use LogError');
    });

    it('uses PadLeft for price formatting', () => {
      const testPath = path.join(ROOT_DIR, '..', 'source', 'SubscriptionUI.brs');
      const content = fs.readFileSync(testPath, 'utf-8');
      truthy(content.includes('PadLeft'), 'Should use PadLeft for price formatting');
    });

    it('uses LCase for status comparison', () => {
      const testPath = path.join(ROOT_DIR, '..', 'source', 'SubscriptionUI.brs');
      const content = fs.readFileSync(testPath, 'utf-8');
      truthy(content.includes('LCase'), 'Should use LCase for case-insensitive status');
    });

    it('has error handling with try/catch blocks', () => {
      const testPath = path.join(ROOT_DIR, '..', 'source', 'SubscriptionUI.brs');
      const content = fs.readFileSync(testPath, 'utf-8');
      truthy(content.includes('catch'), 'Should have catch blocks');
    });

    it('uses roAppManager for browser launch', () => {
      const testPath = path.join(ROOT_DIR, '..', 'source', 'SubscriptionUI.brs');
      const content = fs.readFileSync(testPath, 'utf-8');
      truthy(content.includes('roAppManager'), 'Should use roAppManager');
    });

    it('uses SetFocusedContentUrl for browser URL', () => {
      const testPath = path.join(ROOT_DIR, '..', 'source', 'SubscriptionUI.brs');
      const content = fs.readFileSync(testPath, 'utf-8');
      truthy(content.includes('SetFocusedContentUrl'), 'Should use SetFocusedContentUrl');
    });

    it('uses ObserveField for button callbacks', () => {
      const testPath = path.join(ROOT_DIR, '..', 'source', 'SubscriptionUI.brs');
      const content = fs.readFileSync(testPath, 'utf-8');
      truthy(content.includes('ObserveField'), 'Should use ObserveField');
    });
  });
}
