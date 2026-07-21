const assert = require('assert');

class FakeFirestore {
  constructor(seed = {}) {
    this.store = new Map();
    for (const [path, document] of Object.entries(seed)) {
      this.store.set(path, cloneWithoutId(document));
    }
  }

  collection(path) {
    return new FakeCollectionRef(this, path);
  }

  async runTransaction(callback) {
    const transaction = new FakeTransaction(this);
    const response = await callback(transaction);
    transaction.commit();
    return response;
  }

  docData(path) {
    return clone(this.store.get(path));
  }

  collectionData(path) {
    const depth = path.split('/').length + 1;
    return [...this.store.entries()]
      .filter(([documentPath]) => (
        documentPath.startsWith(`${path}/`) &&
        documentPath.split('/').length === depth
      ))
      .map(([documentPath, document]) => ({
        id: documentPath.split('/').pop(),
        ...clone(document),
      }));
  }
}

class FakeCollectionRef {
  constructor(db, path) {
    this.db = db;
    this.path = path;
  }

  doc(id) {
    return new FakeDocumentRef(this.db, `${this.path}/${id}`);
  }

  where(field, op, value) {
    return new FakeQuery(this.db, this.path, [{field, op, value}]);
  }
}

class FakeDocumentRef {
  constructor(db, path) {
    this.db = db;
    this.path = path;
    this.id = path.split('/').pop();
  }

  collection(name) {
    return new FakeCollectionRef(this.db, `${this.path}/${name}`);
  }
}

class FakeQuery {
  constructor(db, path, filters, maxResults = null) {
    this.db = db;
    this.path = path;
    this.filters = filters;
    this.maxResults = maxResults;
  }

  where(field, op, value) {
    return new FakeQuery(this.db, this.path, [
      ...this.filters,
      {field, op, value},
    ], this.maxResults);
  }

  limit(maxResults) {
    assert(Number.isInteger(maxResults) && maxResults > 0);
    return new FakeQuery(this.db, this.path, this.filters, maxResults);
  }
}

class FakeTransaction {
  constructor(db) {
    this.db = db;
    this.writes = [];
  }

  async get(target) {
    if (target instanceof FakeQuery) {
      return new FakeQuerySnapshot(queryDocs(this.db.store, target));
    }
    return new FakeDocumentSnapshot(target, this.db.store.get(target.path));
  }

  update(ref, document) {
    this.writes.push({type: 'update', path: ref.path, document: clone(document)});
  }

  set(ref, document) {
    this.writes.push({type: 'set', path: ref.path, document: clone(document)});
  }

  commit() {
    for (const write of this.writes) {
      if (write.type === 'set') {
        this.db.store.set(write.path, cloneWithoutId(write.document));
        continue;
      }
      const existing = this.db.store.get(write.path);
      if (!existing) {
        throw new Error(`Missing document for update: ${write.path}`);
      }
      this.db.store.set(write.path, {
        ...existing,
        ...cloneWithoutId(write.document),
      });
    }
  }
}

class FakeDocumentSnapshot {
  constructor(ref, document) {
    this.ref = ref;
    this.id = ref.id;
    this.exists = document != null;
    this.document = clone(document);
  }

  data() {
    return clone(this.document);
  }
}

class FakeQuerySnapshot {
  constructor(docs) {
    this.docs = docs;
  }

  forEach(callback) {
    this.docs.forEach(callback);
  }
}

function queryDocs(store, query) {
  const depth = query.path.split('/').length + 1;
  const docs = [...store.entries()]
    .filter(([path]) => (
      path.startsWith(`${query.path}/`) &&
      path.split('/').length === depth
    ))
    .filter(([, document]) => query.filters.every((filter) => {
      assert.strictEqual(filter.op, '==');
      return document[filter.field] === filter.value;
    }))
    .map(([path, document]) => (
      new FakeDocumentSnapshot(new FakeDocumentRef(null, path), document)
    ));
  return query.maxResults == null ? docs : docs.slice(0, query.maxResults);
}

function clone(value) {
  if (value == null) {
    return value;
  }
  return JSON.parse(JSON.stringify(value));
}

function cloneWithoutId(value) {
  const cloned = clone(value);
  if (cloned && Object.prototype.hasOwnProperty.call(cloned, 'id')) {
    delete cloned.id;
  }
  return cloned;
}

module.exports = {FakeFirestore};
