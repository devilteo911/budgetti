import 'package:budgetti/l10n/app_localizations_en.dart';
import 'package:budgetti/l10n/app_localizations_it.dart';
import 'package:flutter_test/flutter_test.dart';

/// The count strings of the sync snackbars and the sync-setup screen: "1 nuove
/// transazioni" read wrong, so each says one thing at 1 and another otherwise.
void main() {
  final en = AppLocalizationsEn();
  final it = AppLocalizationsIt();

  test('new drafts', () {
    expect(it.setNewDrafts(1), '1 nuova transazione da rivedere');
    expect(it.setNewDrafts(2), '2 nuove transazioni da rivedere');
    expect(en.setNewDrafts(1), '1 new transaction to review');
    expect(en.setNewDrafts(2), '2 new transactions to review');
  });

  test('unrecognized notifications and e-mails', () {
    expect(it.setUnreadNotifications(1), '1 notifica non riconosciuta');
    expect(it.setUnreadNotifications(2), '2 notifiche non riconosciute');
    expect(en.setUnreadNotifications(1), '1 unrecognized notification');
    expect(en.setUnreadNotifications(2), '2 unrecognized notifications');
    expect(it.setUnreadEmails(1), '1 email non riconosciuta');
    expect(it.setUnreadEmails(2), '2 email non riconosciute');
    expect(en.setUnreadEmails(1), '1 unrecognized email');
    expect(en.setUnreadEmails(2), '2 unrecognized emails');
  });

  test('statement import counts', () {
    expect(it.setCountAlreadyPresent(1), '1 già presente');
    expect(it.setCountAlreadyPresent(2), '2 già presenti');
    expect(it.setCountUnreadableRows(1), '1 riga illeggibile');
    expect(it.setCountUnreadableRows(2), '2 righe illeggibili');
    expect(en.setCountUnreadableRows(1), '1 unreadable row');
    expect(en.setCountUnreadableRows(2), '2 unreadable rows');
  });

  test('days to scan', () {
    expect(it.setDaysCount(1), '1 giorno');
    expect(it.setDaysCount(30), '30 giorni');
    expect(en.setDaysCount(1), '1 day');
    expect(en.setDaysCount(30), '30 days');
  });

  test('sync setup: how many transactions', () {
    expect(it.authServerHasData(1),
        'Il server ha già dati per questo account (1 transazione).');
    expect(it.authServerHasData(2),
        'Il server ha già dati per questo account (2 transazioni).');
    expect(en.authServerHasData(1),
        'The server already has data for this account (1 transaction).');
    expect(en.authUseServerDataSubtitle(2),
        'Download everything to this device (2 transactions)');
    expect(it.authUploadDeviceDataSubtitle(1),
        'Invia tutti i dati locali al server (1 transazione)');
    expect(en.authUploadDeviceDataSubtitle(2),
        'Push all local data to the server (2 transactions)');
  });

  test('import, linked payments and the recent list', () {
    expect(en.importSuccess(1), 'Successfully imported 1 transaction');
    expect(en.importSuccess(2), 'Successfully imported 2 transactions');
    expect(it.importSuccess(1), 'Transazioni importate: 1');
    expect(it.instLinkedCount(1), '· 1 collegato');
    expect(it.instLinkedCount(2), '· 2 collegati');
    expect(en.instLinkedCount(1), '· 1 linked');
    expect(it.dashLastCount(1), 'Ultima');
    expect(it.dashLastCount(5), 'Ultimi 5');
    expect(en.dashLastCount(1), 'Last 1');
    expect(en.dashLastCount(5), 'Last 5');
  });

  test('zero is plural', () {
    expect(it.setNewDrafts(0), '0 nuove transazioni da rivedere');
    expect(en.setNewDrafts(0), '0 new transactions to review');
  });
}
