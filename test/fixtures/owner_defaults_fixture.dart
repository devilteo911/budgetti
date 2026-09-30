// The owner's default categories and tags as the phone exported them on
// 2026-09-30, after every copy of five defaults had been soft-deleted in one
// second (10:26:09). Structure, ids' shape, icons, colours and stamps are the
// real ones; personal names and account ids are replaced. Rows are in rowid
// (insertion) order: legacy seeds, the owner's own seed family, two later seed
// families. The owner's user-made categories are left out — nothing here needs
// them.

/// (id, name, type, iconCode, colorHex, isDeleted, lastUpdated in seconds)
typedef CatRow = (String, String, String, int, int, bool, int);

/// (id, name, colorHex, isDeleted, lastUpdated in seconds)
typedef TagRow = (String, String, int, bool, int);

/// The five defaults that vanished: no live copy left, yet live transactions
/// and budgets still name them.
const vanishedDefaults = ['Groceries', 'Shopping', 'Bills', 'Health', 'Entertainment'];

/// The owner's own copies of those five, the ones a restore should bring back.
const vanishedOwnIds = [
  'uidA_cat_Groceries',
  'uidA_cat_Shopping',
  'uidA_cat_Bills',
  'uidA_cat_Health',
  'uidA_cat_Entertainment',
];

/// The second the five disappeared.
const theBatchSecond = 1790756769;

const exportedCategories = <CatRow>[
  ('1767781286727Groceries', 'Groceries', 'expense', 57954, 4283215696, true, 1784586464),
  ('1767781286735Transport', 'Transport', 'expense', 57675, 4280391411, false, 1784585637),
  ('1767781286736Dining', 'Dining', 'expense', 57924, 4294940672, true, 1784586457),
  ('1767781286736Shopping', 'Shopping', 'expense', 59600, 4288423856, true, 1784586470),
  ('1767781286736Entertainment', 'Entertainment', 'expense', 58022, 4294924066, true, 1784586461),
  ('1767781286736Health', 'Health', 'expense', 58009, 4294198070, true, 1784586467),
  ('1767781286736Bills', 'Bills', 'expense', 59469, 4284513675, true, 1784586455),
  ('1767781286736Salary', 'Salary', 'income', 57357, 4278228616, false, 1784585637),
  ('1767781286736Freelance', 'Freelance', 'income', 59647, 4282339765, false, 1784585637),
  ('1767781286736Investments', 'Investments', 'income', 60232, 4284955319, false, 1784585637),
  ('uidA_cat_Groceries', 'Groceries', 'expense', 58206, 4283215696, true, 1790756769),
  ('uidA_cat_Transport', 'Car', 'expense', 57815, 4280391411, false, 1785452380),
  ('uidA_cat_Dining', 'Eating out', 'expense', 57946, 4294940672, false, 1769035244),
  ('uidA_cat_Shopping', 'Shopping', 'expense', 59600, 4288423856, true, 1790756769),
  ('uidA_cat_Entertainment', 'Entertainment', 'expense', 58022, 4294924066, true, 1790756769),
  ('uidA_cat_Health', 'Health', 'expense', 58009, 4294198070, true, 1790756769),
  ('uidA_cat_Bills', 'Bills', 'expense', 58136, 4284513675, true, 1790756769),
  ('uidA_cat_Salary', 'Refunds', 'income', 58359, 4283215696, false, 1768672411),
  ('uidA_cat_Freelance', 'Client A', 'income', 58359, 4288423856, false, 1768672394),
  ('uidA_cat_Investments', 'Client B', 'income', 58359, 4280391411, false, 1768672401),
  ('uidB_cat_Groceries', 'Groceries', 'expense', 57954, 4283215696, true, 1790756769),
  ('uidB_cat_Transport', 'Transport', 'expense', 57675, 4280391411, true, 1790756769),
  ('uidB_cat_Dining', 'Dining', 'expense', 57924, 4294940672, true, 1790756769),
  ('uidB_cat_Shopping', 'Shopping', 'expense', 59600, 4288423856, true, 1790756769),
  ('uidB_cat_Entertainment', 'Entertainment', 'expense', 58022, 4294924066, true, 1790756769),
  ('uidB_cat_Health', 'Health', 'expense', 58009, 4294198070, true, 1790756769),
  ('uidB_cat_Bills', 'Bills', 'expense', 59469, 4284513675, true, 1790756769),
  ('uidB_cat_Salary', 'Salary', 'income', 57357, 4278228616, true, 1790756769),
  ('uidB_cat_Freelance', 'Freelance', 'income', 59647, 4282339765, true, 1790756769),
  ('uidB_cat_Investments', 'Investments', 'income', 60232, 4284955319, true, 1790756769),
  ('local_cat_Groceries', 'Groceries', 'expense', 57954, 4283215696, true, 1790756769),
  ('local_cat_Transport', 'Transport', 'expense', 57675, 4280391411, true, 1790756769),
  ('local_cat_Dining', 'Dining', 'expense', 57924, 4294940672, true, 1790756769),
  ('local_cat_Shopping', 'Shopping', 'expense', 59600, 4288423856, true, 1790756769),
  ('local_cat_Entertainment', 'Entertainment', 'expense', 58022, 4294924066, true, 1790756769),
  ('local_cat_Health', 'Health', 'expense', 58009, 4294198070, true, 1790756769),
  ('local_cat_Bills', 'Bills', 'expense', 59469, 4284513675, true, 1790756769),
  ('local_cat_Salary', 'Salary', 'income', 57357, 4278228616, true, 1790756769),
  ('local_cat_Freelance', 'Freelance', 'income', 59647, 4282339765, true, 1790756769),
  ('local_cat_Investments', 'Investments', 'income', 60232, 4284955319, true, 1790756769),
];

const exportedTags = <TagRow>[
  ('1767781286761Vacation', 'Vacation', 4293467747, false, 1784585637),
  ('1767781286762Family', 'Family', 4288423856, false, 1784585637),
  ('1767781286762Work', 'Work', 4282339765, false, 1784585637),
  ('1767781286762Personal', 'Personal', 4278238420, false, 1784585637),
  ('1767781286762Gift', 'Gift', 4294924066, false, 1784585637),
  ('uidA_tag_Vacation', 'Vacation', 4293467747, true, 1790756769),
  ('uidA_tag_Family', 'Club', 4278430196, false, 1768700143),
  ('uidA_tag_Work', 'Work', 4282339765, true, 1790756769),
  ('uidA_tag_Personal', 'Personal', 4278238420, true, 1768672472),
  ('uidA_tag_Gift', 'Gift', 4294924066, true, 1790756769),
  ('uidB_tag_Vacation', 'Vacation', 4293467747, true, 1790756769),
  ('uidB_tag_Family', 'Family', 4288423856, true, 1790756769),
  ('uidB_tag_Work', 'Work', 4282339765, true, 1790756769),
  ('uidB_tag_Personal', 'Personal', 4278238420, true, 1790756769),
  ('uidB_tag_Gift', 'Gift', 4294924066, true, 1790756769),
  ('local_tag_Vacation', 'Vacation', 4293467747, true, 1790756769),
  ('local_tag_Family', 'Family', 4288423856, true, 1790756769),
  ('local_tag_Work', 'Work', 4282339765, true, 1790756769),
  ('local_tag_Personal', 'Personal', 4278238420, true, 1790756769),
  ('local_tag_Gift', 'Gift', 4294924066, true, 1790756769),
];
