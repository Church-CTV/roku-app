/**
 * Roku Environment Mocks
 * 
 * Mocks for Roku-specific APIs that cannot run in Node.js.
 * Use these in unit tests to isolate BrightScript logic.
 */

// ============================================================
// roSGNode Mock
// ============================================================

export class MockRoSGNode {
  constructor(type = 'ContentNode') {
    this._type = type;
    this._fields = {};
    this._children = [];
    this._observers = {};
    this.id = '';
    this.visible = true;
  }

  // Field access
  getField(name) {
    return this._fields[name];
  }

  setField(name, value) {
    this._fields[name] = value;
    // Trigger observers
    if (this._observers[name]) {
      for (const handler of this._observers[name]) {
        try { handler(); } catch(e) {}
      }
    }
  }

  hasField(name) {
    return name in this._fields;
  }

  addFields(fields) {
    for (const [key, value] of Object.entries(fields)) {
      this._fields[key] = value;
    }
  }

  // Children
  appendChild(child) {
    this._children.push(child);
    return child;
  }

  removeChild(child) {
    const idx = this._children.indexOf(child);
    if (idx >= 0) this._children.splice(idx, 1);
  }

  getChild(index) {
    return this._children[index];
  }

  getChildren(start = 0, count = this._children.length - start) {
    return this._children.slice(start, start + count);
  }

  getChildCount() {
    return this._children.length;
  }

  // Observers
  observeField(name, handler) {
    if (!this._observers[name]) this._observers[name] = [];
    this._observers[name].push(handler);
  }

  unobserveField(name) {
    delete this._observers[name];
  }

  // Node methods
  findNode(id) {
    if (this.id === id) return this;
    for (const child of this._children) {
      const found = child.findNode(id);
      if (found) return found;
    }
    return null;
  }

  clone(deep = false) {
    const clone = new MockRoSGNode(this._type);
    clone._fields = { ...this._fields };
    if (deep) {
      clone._children = this._children.map(c => c.clone(true));
    }
    return clone;
  }

  isSameNode(other) {
    return this === other;
  }

  setFocus(focus) {
    this._focused = focus;
  }

  callFunc(name, arg) {
    if (typeof this[name] === 'function') {
      return this[name](arg);
    }
    return null;
  }

  update(fields, merge = false) {
    for (const [key, value] of Object.entries(fields)) {
      this._fields[key] = value;
    }
  }

  // Dynamic property access for BrightScript-style code
  get [Symbol.toPrimitive]() {
    return () => `[MockRoSGNode:${this._type}]`;
  }
}

// ============================================================
// roSGScreen Mock
// ============================================================

export class MockRoSGScreen {
  constructor() {
    this._globalNode = new MockRoSGNode('Global');
    this._scenes = [];
  }

  getGlobalNode() {
    return this._globalNode;
  }

  CreateScene(componentName) {
    const scene = new MockRoSGNode(componentName);
    this._scenes.push(scene);
    return scene;
  }

  SetMessagePort(port) {
    this._port = port;
  }

  Show() {
    this._visible = true;
  }
}

// ============================================================
// roMessagePort Mock
// ============================================================

export class MockRoMessagePort {
  constructor() {
    this._messages = [];
  }

  pushMessage(msg) {
    this._messages.push(msg);
  }

  popMessage() {
    return this._messages.shift();
  }

  isEmpty() {
    return this._messages.length === 0;
  }
}

// ============================================================
// roSGScreenEvent Mock
// ============================================================

export class MockRoSGScreenEvent {
  constructor(type, data = {}) {
    this._type = type;
    this._data = data;
    this._closed = false;
  }

  IsScreenClosed() {
    return this._closed;
  }

  GetType() {
    return this._type;
  }

  GetRoSGNode() {
    return this._data.node || null;
  }
}

// ============================================================
// roDateTime Mock
// ============================================================

export class MockRoDateTime {
  constructor(date = new Date()) {
    this._date = date;
  }

  ToLocalTime() {
    return this;
  }

  GetHours() {
    return this._date.getHours();
  }

  GetMinutes() {
    return this._date.getMinutes();
  }

  GetSeconds() {
    return this._date.getSeconds();
  }

  GetYear() {
    return this._date.getFullYear();
  }

  GetMonth() {
    return this._date.getMonth() + 1;
  }

  GetDay() {
    return this._date.getDate();
  }

  AsInteger() {
    return this._date.getTime();
  }
}

// ============================================================
// roTimespan Mock
// ============================================================

export class MockRoTimespan {
  constructor() {
    this._start = Date.now();
  }

  Mark() {
    this._start = Date.now();
  }

  TotalMilliseconds() {
    return Date.now() - this._start;
  }
}

// ============================================================
// roUrlTransfer Mock
// ============================================================

export class MockRoUrlTransfer {
  constructor() {
    this._url = '';
    this._headers = {};
    this._async = false;
    this._port = null;
    this._responses = new Map();
  }

  set url(value) {
    this._url = value;
  }

  get url() {
    return this._url;
  }

  SetHeaders(headers) {
    this._headers = { ...this._headers, ...headers };
  }

  SetAsync(async) {
    this._async = async;
  }

  SetMessagePort(port) {
    this._port = port;
  }

  // Stub response for testing
  stubResponse(url, body, statusCode = 200) {
    this._responses.set(url, { body, statusCode });
  }

  GetToString() {
    const response = this._responses.get(this._url);
    return response ? response.body : '';
  }

  GetToByteArray() {
    const response = this._responses.get(this._url);
    return response ? response.body : '';
  }

  IsRunning() {
    return false;
  }

  AsyncGetToString() {
    return true;
  }
}

// ============================================================
// roInputEvent Mock
// ============================================================

export class MockRoInputEvent {
  constructor(data = {}) {
    this._data = data;
  }

  IsInput() {
    return true;
  }

  GetInfo() {
    return this._data;
  }
}

// ============================================================
// roUrlEvent Mock
// ============================================================

export class MockRoUrlEvent {
  constructor(data = '') {
    this._data = data;
  }

  GetString() {
    return this._data;
  }

  GetUrl() {
    return typeof this._data === 'string' ? this._data : '';
  }
}

// ============================================================
// Global Mock Functions
// ============================================================

export function createMockRokuEnv() {
  const env = {
    CreateObject: (type, ...args) => {
      switch (type) {
        case 'roSGScreen':
          return new MockRoSGScreen();
        case 'roSGNode':
          return new MockRoSGNode(args[0] || 'ContentNode');
        case 'roMessagePort':
          return new MockRoMessagePort();
        case 'roDateTime':
          return new MockRoDateTime(args[0]);
        case 'roTimespan':
          return new MockRoTimespan();
        case 'roUrlTransfer':
          return new MockRoUrlTransfer();
        case 'roSGScreenEvent':
          return new MockRoSGScreenEvent(args[0], args[1]);
        case 'roInputEvent':
          return new MockRoInputEvent(args[0]);
        case 'roUrlEvent':
          return new MockRoUrlEvent(args[0]);
        default:
          return new MockRoSGNode(type);
      }
    },

    ParseJson: (str) => JSON.parse(str),
    FormatJson: (obj) => JSON.stringify(obj),
    CreateObject,
    ReadAsciiFile: async (filePath) => {
      const realFs = await import('fs');
      const resolved = filePath.replace('pkg:/', ROOT_DIR + '/');
      try {
        return realFs.readFileSync(resolved, 'utf-8');
      } catch {
        return null;
      }
    },
  };

  return env;
}

/**
 * Helper: Simulate BrightScript function execution in Node.js context
 * Parses and executes a simplified subset of BrightScript
 */
export function simulateBrightScript(code, globals = {}) {
  // Replace BrightScript-specific syntax with JavaScript equivalents
  let jsCode = code
    // Comments
    .replace(/'.*/g, '// $&')
    // Type declarations
    .replace(/\bas\b/g, '/*as*/')
    .replace(/as dynamic/g, '')
    .replace(/as String/g, '')
    .replace(/as Object/g, '')
    .replace(/as Boolean/g, '')
    .replace(/as Integer/g, '')
    .replace(/as Float/g, '')
    // BrightScript keywords -> JavaScript
    .replace(/\bif\b/g, 'if')
    .replace(/\bthen\b/g, '')
    .replace(/\belse\b/g, 'else')
    .replace(/\bend if\b/g, '}')
    .replace(/\bfor each\s+(\w+)\sin\b/g, 'for (const $1 of')
    .replace(/\bfor\s+(\w+)\s*=\s*(\d+)\s+to\b/g, 'for (let $1 = $2; $1 <=')
    .replace(/\bwhile\b/g, 'while')
    .replace(/\bend while\b/g, '}')
    .replace(/\bend for\b/g, '}')
    .replace(/\bend sub\b/g, '}')
    .replace(/\bend function\b/g, '}')
    .replace(/\bsub\b/g, 'function')
    .replace(/\bfunction\b/g, 'function')
    .replace(/\breturn\b/g, 'return')
    .replace(/\btrue\b/g, 'true')
    .replace(/\bfalse\b/g, 'false')
    .replace(/\binvalid\b/g, 'null')
    .replace(/\band\b/g, '&&')
    .replace(/\bor\b/g, '||')
    .replace(/\bnot\b/g, '!')
    .replace(/\bmod\b/g, '%')
    // BrightScript operators
    .replace(/\\(?!\$)/g, '|')  // backslash integer division -> bitwise or (approximation)
    // Array literal
    .replace(/\[\s*\]/g, '[]')
    // Associative array literal
    .replace(/\{\s*\}/g, '{}');

  // This is a rough approximation - full parsing requires a proper BrightScript parser
  return jsCode;
}
