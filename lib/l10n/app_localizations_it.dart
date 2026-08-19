// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Italian (`it`).
class AppLocalizationsIt extends AppLocalizations {
  AppLocalizationsIt([String locale = 'it']) : super(locale);

  @override
  String get appName => 'Budgetti';

  @override
  String get commonCancel => 'Annulla';

  @override
  String get commonSave => 'Salva';

  @override
  String get commonDelete => 'Elimina';

  @override
  String get commonEdit => 'Modifica';

  @override
  String get commonAdd => 'Aggiungi';

  @override
  String get commonClose => 'Chiudi';

  @override
  String get commonConfirm => 'Conferma';

  @override
  String get commonOk => 'OK';

  @override
  String get commonRetry => 'Riprova';

  @override
  String get commonError => 'Errore';

  @override
  String get commonLoading => 'Caricamento…';

  @override
  String get commonDone => 'Fatto';

  @override
  String get commonBack => 'Indietro';

  @override
  String get commonToday => 'Oggi';

  @override
  String get commonNone => 'Nessuno';

  @override
  String get commonAll => 'Tutti';

  @override
  String get commonYes => 'Sì';

  @override
  String get commonNo => 'No';

  @override
  String get commonIncome => 'Entrata';

  @override
  String get commonExpense => 'Spesa';

  @override
  String get commonTransfer => 'Trasferimento';

  @override
  String get commonAmount => 'Importo';

  @override
  String get commonDate => 'Data';

  @override
  String get commonCategory => 'Categoria';

  @override
  String get commonWallet => 'Portafoglio';

  @override
  String get commonDescription => 'Descrizione';

  @override
  String get commonTags => 'Tag';

  @override
  String get commonSearch => 'Cerca';

  @override
  String get commonNoData => 'Nessun dato';

  @override
  String get commonSystem => 'Sistema';

  @override
  String get commonUndo => 'Annulla';

  @override
  String get authConnectionError => 'Errore di connessione';

  @override
  String get authProfileMissing => 'Profilo mancante (errore)';

  @override
  String authDetailedError(String error) {
    return 'Errore dettagliato: $error';
  }

  @override
  String get authLoginFailed => 'Accesso non riuscito';

  @override
  String get authCannotReachServer =>
      'Impossibile raggiungere il server. Controlla l\'URL in Impostazioni > Integrazioni.';

  @override
  String get authLoginTagline => 'Gestisci le tue finanze da professionista';

  @override
  String get authEmail => 'Email';

  @override
  String get authPassword => 'Password';

  @override
  String get authLogIn => 'Accedi';

  @override
  String get authSetServer => 'Imposta server';

  @override
  String get authWhoAreYou => 'Chi sei?';

  @override
  String get authChooseUsername => 'Scegli un nome utente';

  @override
  String get authUsernameHint => 'Dicci come chiamarti nell\'app.';

  @override
  String get authUsername => 'Nome utente';

  @override
  String authUsernameMinLength(int min) {
    return 'Il nome utente deve avere almeno $min caratteri';
  }

  @override
  String get authGetStarted => 'Inizia';

  @override
  String get authSyncSetupTitle => 'Configura la sincronizzazione';

  @override
  String get authSyncSetupSubtitle =>
      'Come devono allinearsi questo dispositivo e il server?';

  @override
  String get authCheckingServer => 'Controllo del server…';

  @override
  String get authServerUnreachable => 'Impossibile raggiungere il server.';

  @override
  String authServerHasData(int count) {
    return 'Il server ha già dati per questo account ($count transazioni).';
  }

  @override
  String get authServerNoData =>
      'Il server non ha ancora dati per questo account.';

  @override
  String get authRetrySubtitle => 'Controlla di nuovo la connessione al server';

  @override
  String get authUseServerData => 'Usa i dati del server';

  @override
  String authUseServerDataSubtitle(int count) {
    return 'Scarica tutto su questo dispositivo ($count transazioni)';
  }

  @override
  String get authUploadDeviceData => 'Carica i dati di questo dispositivo';

  @override
  String authUploadDeviceDataSubtitle(int count) {
    return 'Invia tutti i dati locali al server ($count transazioni)';
  }

  @override
  String get authRestoreBackup => 'Ripristina un file di backup';

  @override
  String get authRestoreBackupSubtitle =>
      'Importa un backup JSON di Budgetti, poi caricalo sul server';

  @override
  String get authContinueWithoutSync => 'Continua senza sincronizzare';

  @override
  String get authContinueWithoutSyncSubtitle =>
      'Mantieni per ora i dati locali e del server così come sono';

  @override
  String get authActionDownload => 'Download';

  @override
  String get authActionUpload => 'Caricamento';

  @override
  String get authActionRestore => 'Ripristino';

  @override
  String authActionFailed(String action, String error) {
    return '$action non riuscito: $error';
  }

  @override
  String get authProfileTitle => 'Profilo';

  @override
  String get authUser => 'Utente';

  @override
  String get authAvatarUpdated => 'Foto profilo aggiornata';

  @override
  String authAvatarSaveError(String error) {
    return 'Errore nel salvataggio dell\'immagine: $error';
  }

  @override
  String get authSignOut => 'Esci';

  @override
  String get authNavDashboard => 'Dashboard';

  @override
  String get authNavHistory => 'Storico';

  @override
  String get authNavStats => 'Statistiche';

  @override
  String get authNavSettings => 'Impostazioni';

  @override
  String get dashConnectivityIssue => 'Problema di connessione';

  @override
  String get dashConnectivityMessage =>
      'Impossibile raggiungere il server. Controlla la connessione.';

  @override
  String get dashSyncFailed => 'Sincronizzazione non riuscita';

  @override
  String get dashNoAccounts => 'Nessun conto trovato';

  @override
  String get dashErrorCalculatingStats =>
      'Errore nel calcolo delle statistiche';

  @override
  String get dashSetUpBudgets => 'Imposta i budget';

  @override
  String get dashSetUpBudgetsSubtitle =>
      'Traccia le spese per categoria ogni mese';

  @override
  String get dashMonthlyBudgetLabel => 'Budget mensile';

  @override
  String get dashCategoriesLabel => 'Categorie';

  @override
  String get dashBudgetSaturation => 'Saturazione budget';

  @override
  String dashError(String error) {
    return 'Errore: $error';
  }

  @override
  String get dashNoBudgets =>
      'Nessun budget impostato. Vai alla scheda Budget per impostare i tuoi limiti!';

  @override
  String get dashTotalBalance => 'Saldo totale';

  @override
  String get dashTrend30d => '30g';

  @override
  String get dashWalletsLabel => 'Portafogli';

  @override
  String get dashWalletsLoadError => 'Impossibile caricare i portafogli';

  @override
  String get dashNoWallets => 'Ancora nessun portafoglio';

  @override
  String dashWalletsMore(int count) {
    return 'altri $count';
  }

  @override
  String get dashStatIn => 'Entrate';

  @override
  String get dashStatOut => 'Uscite';

  @override
  String get dashStatNet => 'Netto';

  @override
  String get dashStillOwedLabel => 'Ancora da pagare';

  @override
  String dashPerMonth(String amount) {
    return '$amount al mese';
  }

  @override
  String get dashPlansLabel => 'Piani';

  @override
  String dashMorePlans(int count) {
    return '+$count altri';
  }

  @override
  String dashNextDue(String date) {
    return 'Prossima $date';
  }

  @override
  String get dashThisMonthLabel => 'Questo mese';

  @override
  String get dashExpenses => 'Spese';

  @override
  String get dashRecentLabel => 'Recenti';

  @override
  String dashLastCount(int count) {
    return 'Ultimi $count';
  }

  @override
  String get dashAllLabel => 'Tutte';

  @override
  String get dashNoTransactions => 'Ancora nessuna transazione';

  @override
  String get dashYesterdayShort => 'IERI';

  @override
  String dashDaysAgoShort(int days) {
    return '${days}G';
  }

  @override
  String get budgetScreenTitle => 'Budget';

  @override
  String get budgetSortUtilization => 'Utilizzo';

  @override
  String get budgetSortAlphabetical => 'Alfabetico';

  @override
  String get budgetSortLimitHighLow => 'Limite: dal più alto';

  @override
  String get budgetSortLimitLowHigh => 'Limite: dal più basso';

  @override
  String get budgetTracked => 'TRACCIATI';

  @override
  String get budgetSectionUnset => 'SENZA LIMITE';

  @override
  String get budgetNoCategories => 'NESSUNA CATEGORIA';

  @override
  String get budgetEmptyHint =>
      'Aggiungi prima le categorie di spesa per iniziare a tracciare i budget.';

  @override
  String get budgetErrorLabel => 'ERRORE';

  @override
  String get budgetUpdated => 'Budget aggiornato';

  @override
  String budgetSaveError(String error) {
    return 'Errore nel salvataggio del budget: $error';
  }

  @override
  String get budgetMonthlyLimit => 'LIMITE MENSILE';

  @override
  String get budgetAmountHint => '0,00';

  @override
  String get budgetEnterLimit => 'Inserisci un limite';

  @override
  String get budgetInvalid => 'Non valido';

  @override
  String get budgetMustBePositive => 'Deve essere positivo';

  @override
  String get budgetClear => 'Rimuovi';

  @override
  String get budgetUpdate => 'Aggiorna';

  @override
  String get budgetCleared => 'Budget rimosso';

  @override
  String budgetUtilizationOf(String month) {
    return 'UTILIZZO  ·  $month';
  }

  @override
  String budgetNoBudgetsSet(String month) {
    return 'NESSUN BUDGET  ·  $month';
  }

  @override
  String get budgetTapToSet =>
      'Tocca una categoria qui sotto per impostare un limite.';

  @override
  String get budgetSpent => 'SPESO';

  @override
  String get budgetBudgeted => 'BUDGET';

  @override
  String get budgetRemaining => 'RIMANENTE';

  @override
  String get budgetOver => 'OLTRE';

  @override
  String get budgetNoLimit => 'NESSUN LIMITE · TOCCA PER IMPOSTARE';

  @override
  String get budgetSet => 'IMPOSTA';

  @override
  String get instScreenTitle => 'Pagamenti a rate';

  @override
  String get instActive => 'ATTIVI';

  @override
  String get instSettled => 'ESTINTI';

  @override
  String get instStillOwed => 'ANCORA DA PAGARE';

  @override
  String instMonthlyActive(String amount, int count) {
    return '$amount / mese · $count attivi';
  }

  @override
  String get instDeletePlanTitle => 'Eliminare il piano?';

  @override
  String instDeletePlanBody(String name) {
    return '\"$name\" verrà rimosso.';
  }

  @override
  String instPerMo(String amount) {
    return '$amount/mese';
  }

  @override
  String instPaidOf(int paid, int total) {
    return '$paid/$total pagate';
  }

  @override
  String instLinkedCount(int count) {
    return '· $count collegati';
  }

  @override
  String get instSettledLabel => 'Estinto';

  @override
  String instRemainingNext(String amount, String date) {
    return '$amount rimanenti · prossima $date';
  }

  @override
  String get instNoPlans => 'NESSUN PIANO';

  @override
  String get instEmptyHint =>
      'Aggiungi un acquisto che stai pagando a rate mensili e qui vedi quanto ti resta da pagare.';

  @override
  String get instAddPlan => 'Aggiungi un piano';

  @override
  String instSaveError(String error) {
    return 'Errore nel salvataggio del piano: $error';
  }

  @override
  String get instNewPlan => 'NUOVO PIANO';

  @override
  String get instEditPlan => 'MODIFICA PIANO';

  @override
  String get instWhatFor => 'Per cosa è';

  @override
  String get instWhatForHint => 'Divano, laptop, vacanza…';

  @override
  String get instRequired => 'Obbligatorio';

  @override
  String get instTotal => 'Totale';

  @override
  String get instInvalid => 'Non valido';

  @override
  String get instMustBePositive => 'Deve essere positivo';

  @override
  String get instAtLeast1 => 'Almeno 1';

  @override
  String get instRatesLabel => 'Rate';

  @override
  String get instPerRateHint => 'La rata mensile appare qui';

  @override
  String instPerMonth(String amount) {
    return '$amount / mese';
  }

  @override
  String get instFirstRateOn => 'Prima rata il';

  @override
  String get instCategoryOptional => 'Categoria (opzionale)';

  @override
  String get instWalletOptional => 'Portafoglio (opzionale)';

  @override
  String get instUpdatePlan => 'Aggiorna piano';

  @override
  String instLinkedPaymentsOf(int linked, int due) {
    return 'PAGAMENTI COLLEGATI · $linked/$due';
  }

  @override
  String get instAllAccounted =>
      'Tutte le rate scadute finora sono registrate.';

  @override
  String instMissingRates(int missing, int due) {
    return '$missing delle $due rate scadute finora non hanno una transazione collegata.';
  }

  @override
  String get instUnlink => 'Scollega';

  @override
  String get instNoCandidates => 'Nessuna spesa da collegare.';

  @override
  String get instAttachPayment => 'Collega un pagamento';

  @override
  String get importSelectWalletError => 'Seleziona un portafoglio';

  @override
  String importSuccess(int count) {
    return 'Transazioni importate: $count';
  }

  @override
  String importError(String error) {
    return 'Errore durante l\'importazione: $error';
  }

  @override
  String get importSelectWalletTitle => 'Seleziona portafoglio';

  @override
  String get importPreviewTitle => 'Anteprima importazione';

  @override
  String get importToWallet => 'Importa nel portafoglio';

  @override
  String importFound(int count) {
    return 'Transazioni trovate: $count';
  }

  @override
  String importTotal(String amount) {
    return 'Totale: $amount';
  }

  @override
  String get importConfirm => 'Conferma importazione';

  @override
  String get chartNoDataYear => 'Nessun dato disponibile per quest\'anno';

  @override
  String chartWeekOf(String date) {
    return 'Settimana del $date';
  }

  @override
  String get chartExpenses => 'Spese';

  @override
  String get chartIncome => 'Entrate';

  @override
  String chartWeekShort(int week) {
    return 'S$week';
  }

  @override
  String get uiSelectCategory => 'Seleziona categoria';

  @override
  String get uiNoCategories => 'Nessuna categoria trovata';

  @override
  String get uiSelectWallet => 'Seleziona portafoglio';

  @override
  String get uiAllWallets => 'Tutti i portafogli';

  @override
  String get notifBackupDone => 'Backup automatico completato.';

  @override
  String get notifBackupFailed =>
      'Backup automatico non riuscito. Controlla le impostazioni.';

  @override
  String get notifBudgetAlertTitle => 'Avviso budget';

  @override
  String notifBudgetReached(String category) {
    return 'Hai raggiunto il budget per $category!';
  }

  @override
  String notifBudgetUsedPct(String percent, String category) {
    return 'Hai utilizzato il $percent% del budget per $category.';
  }

  @override
  String get notifDailyTitle => 'Registra le spese';

  @override
  String get notifDailyBody =>
      'Non dimenticare di registrare le spese di oggi!';

  @override
  String get notifBackupProgressTitle => 'Backup in corso...';

  @override
  String get notifBackupSuccessTitle => 'Backup riuscito';

  @override
  String get notifBackupFailedTitle => 'Backup non riuscito';

  @override
  String get notifBackupProgressBody => 'Salvataggio dei dati in corso.';

  @override
  String get notifBackupSuccessBody => 'I tuoi dati sono stati salvati.';

  @override
  String get notifBackupErrorBody =>
      'Si è verificato un errore durante il backup.';

  @override
  String get notifEmailIncome => 'Accredito ricevuto';

  @override
  String get notifEmailReview => 'Bonifico da rivedere';

  @override
  String get notifEmailExpense => 'Pagamento registrato';

  @override
  String get setSettings => 'Impostazioni';

  @override
  String get setAccount => 'Account';

  @override
  String get setProfile => 'Profilo';

  @override
  String get setAppearance => 'Aspetto';

  @override
  String get setAppearanceSubtitle => 'Tavolozza, tema, effetti';

  @override
  String get setPreferences => 'Preferenze';

  @override
  String get setPreferencesSubtitle => 'Valuta, scanner, notifiche';

  @override
  String get setIntegrationsBackup => 'Integrazioni e backup';

  @override
  String get setIntegrationsBackupSubtitle =>
      'Drive, Sheets, backup automatico';

  @override
  String get setData => 'Dati';

  @override
  String get setAbout => 'Informazioni';

  @override
  String get setSourceCode => 'Codice sorgente';

  @override
  String get setSignOut => 'Esci';

  @override
  String get setImportQuicken => 'Importa Quicken (QIF)';

  @override
  String get setImportQuickenSubtitle => 'Carica transazioni da un file .qif';

  @override
  String get setSelectQifFile => 'Seleziona un file .qif';

  @override
  String get setLanguage => 'Lingua';

  @override
  String get setPalette => 'Tavolozza';

  @override
  String get setBrightness => 'Luminosità';

  @override
  String get setThemeLight => 'Chiaro';

  @override
  String get setThemeDark => 'Scuro';

  @override
  String get setEffects => 'Effetti';

  @override
  String get setAmoledBlack => 'Nero AMOLED';

  @override
  String get setAmoledBlackSubtitle => 'Sfondo nero puro in modalità scura';

  @override
  String get setLiquidGlass => 'Vetro liquido';

  @override
  String get setLiquidGlassSubtitle =>
      'Sfocatura su barra di navigazione e fogli';

  @override
  String get setCategories => 'Categorie';

  @override
  String get setTags => 'Tag';

  @override
  String get setWallets => 'Portafogli';

  @override
  String get setNoCategories => 'Ancora nessuna categoria';

  @override
  String get setCreateFirstCategory => 'Crea la tua prima categoria';

  @override
  String get setNoTags => 'Ancora nessun tag';

  @override
  String get setNoWallets => 'Ancora nessun portafoglio';

  @override
  String get setExpenses => 'Spese';

  @override
  String get setIncome => 'Entrate';

  @override
  String get setRestoreDefaults => 'Ripristina predefiniti';

  @override
  String get setRestoreDefaultsTitle => 'Ripristinare i predefiniti?';

  @override
  String get setRestoreCategoriesBody =>
      'Ripristina le categorie predefinite se sono state eliminate o modificate. Le tue categorie personalizzate non verranno toccate.';

  @override
  String get setRestoreTagsBody =>
      'Ripristina i tag predefiniti se sono stati eliminati o modificati. I tuoi tag personalizzati non verranno toccati.';

  @override
  String get setRestore => 'Ripristina';

  @override
  String get setCategoriesRestored => 'Categorie predefinite ripristinate';

  @override
  String get setTagsRestored => 'Tag predefiniti ripristinati';

  @override
  String get setDeleteCategoryTitle => 'Eliminare la categoria?';

  @override
  String get setDeleteTagTitle => 'Elimina tag';

  @override
  String get setDeleteWalletTitle => 'Elimina portafoglio';

  @override
  String setDeleteConfirmBody(String name) {
    return 'Eliminare \'$name\'?';
  }

  @override
  String setDeleteWalletBody(String name) {
    return 'Eliminare \'$name\'? Le transazioni non verranno eliminate ma potrebbero restare senza portafoglio.';
  }

  @override
  String setErrorWithDetails(String error) {
    return 'Errore: $error';
  }

  @override
  String get setNewCategory => 'Nuova categoria';

  @override
  String get setEditCategory => 'Modifica categoria';

  @override
  String get setFieldName => 'Nome';

  @override
  String get setFieldType => 'Tipo';

  @override
  String get setFieldDescription => 'Descrizione (opzionale)';

  @override
  String get setFieldSelectIcon => 'Seleziona icona';

  @override
  String get setCategoryNameHint => 'es. Spese, Affitto...';

  @override
  String get setCategoryDescriptionHint =>
      'Aggiungi una breve nota su questa categoria...';

  @override
  String get setSaveCategory => 'Salva categoria';

  @override
  String get setSelectColor => 'Seleziona colore';

  @override
  String get setNewTag => 'Nuovo tag';

  @override
  String get setEditTag => 'Modifica tag';

  @override
  String get setTagName => 'Nome tag';

  @override
  String get setColor => 'Colore';

  @override
  String get setCreateTag => 'Crea tag';

  @override
  String get setUpdateTag => 'Aggiorna tag';

  @override
  String get setNewWallet => 'Nuovo portafoglio';

  @override
  String get setEditWallet => 'Modifica portafoglio';

  @override
  String get setWalletNameHint => 'Nome portafoglio (es. PayPal, Banca)';

  @override
  String get setInitialAmount => 'Importo iniziale';

  @override
  String get setStartingDate => 'Data di inizio';

  @override
  String get setAllTransactions => 'Tutte le transazioni';

  @override
  String get setSetAsDefault => 'Imposta come predefinito';

  @override
  String get setCreateWallet => 'Crea portafoglio';

  @override
  String get setUpdateWallet => 'Aggiorna portafoglio';

  @override
  String setWalletSince(String date) {
    return 'Dal $date';
  }

  @override
  String get setGeneral => 'Generali';

  @override
  String get setCurrency => 'Valuta';

  @override
  String get setSelectCurrency => 'Seleziona valuta';

  @override
  String get setCurrencyEur => 'Euro';

  @override
  String get setCurrencyUsd => 'Dollaro USA';

  @override
  String get setCurrencyGbp => 'Sterlina britannica';

  @override
  String get setCurrencyJpy => 'Yen giapponese';

  @override
  String get setNotifications => 'Notifiche';

  @override
  String get setFixPermissions => 'Correggi permessi';

  @override
  String get setFixPermissionsSubtitle => 'Tocca per attivare le notifiche';

  @override
  String get setPushNotifications => 'Notifiche push';

  @override
  String get setPushNotificationsSubtitle => 'Avvisi principali di sistema';

  @override
  String get setBudgetAlerts => 'Avvisi budget';

  @override
  String get setBudgetAlertsSubtitle => 'Soglie limite';

  @override
  String get setDailyReminder => 'Promemoria giornaliero';

  @override
  String get setDailyReminderSubtitle => 'Registrazione manuale';

  @override
  String get setReminderTime => 'Orario promemoria';

  @override
  String get setIntegrations => 'Integrazioni';

  @override
  String get setCloudSync => 'Sincronizzazione cloud';

  @override
  String get setServer => 'Server';

  @override
  String get setNotConfigured => 'Non configurato';

  @override
  String get setSyncNow => 'Sincronizza ora';

  @override
  String get setPushEverything => 'Invia tutto';

  @override
  String get setPushEverythingSubtitle =>
      'Carica tutti i dati locali (categorie, tag, portafogli, transazioni, budget) sul server';

  @override
  String get setPullEverything => 'Scarica tutto';

  @override
  String get setPullEverythingSubtitle =>
      'Scarica tutti i dati del server su questo dispositivo';

  @override
  String get setConfigureServerFirst => 'Configura prima l\'URL del server';

  @override
  String setSyncFailed(String error) {
    return 'Sincronizzazione non riuscita: $error';
  }

  @override
  String get setPbServerTitle => 'Server PocketBase';

  @override
  String get setPbHost => 'Host o IP';

  @override
  String get setPbPort => 'Porta';

  @override
  String get setGoogleDrive => 'Google Drive';

  @override
  String get setConnectDrive => 'Connetti Google Drive';

  @override
  String get setConnectDriveSubtitle => 'Backup e ripristino dal cloud';

  @override
  String get setDriveConnected => 'Drive connesso';

  @override
  String get setBackupNow => 'Esegui backup ora';

  @override
  String get setRestoreFromBackup => 'Ripristina da backup';

  @override
  String get setGoogleConnected => 'Connesso a Google';

  @override
  String setSignInFailed(String error) {
    return 'Accesso non riuscito: $error';
  }

  @override
  String get setSignInCancelled => 'Accesso annullato';

  @override
  String get setBackupDone => 'Backup riuscito';

  @override
  String setBackupFailed(String error) {
    return 'Backup non riuscito: $error';
  }

  @override
  String get setNoBackups => 'Nessun backup trovato';

  @override
  String get setSelectBackup => 'Seleziona backup';

  @override
  String get setUnknown => 'Sconosciuto';

  @override
  String get setRestoreDone => 'Ripristino riuscito';

  @override
  String setRestoreFailed(String error) {
    return 'Ripristino non riuscito: $error';
  }

  @override
  String get setGoogleSheets => 'Google Sheets';

  @override
  String get setSpreadsheet => 'Foglio di calcolo';

  @override
  String get setSheetsConfig => 'Configurazione Google Sheets';

  @override
  String get setSpreadsheetId => 'ID foglio di calcolo';

  @override
  String get setSpreadsheetIdHint => 'Dall\'URL del foglio Google';

  @override
  String get setSheetName => 'Nome del foglio';

  @override
  String get setSheetNameHint => 'es. Spese';

  @override
  String get setNeverSynced => 'Mai sincronizzato';

  @override
  String setLastSync(String date) {
    return 'Ultima sincronizzazione: $date';
  }

  @override
  String get setBankEmailSync => 'Sincronizzazione email banca';

  @override
  String get setSyncWidibaEmail => 'Sincronizza email Widiba';

  @override
  String get setSyncWidibaEmailSubtitle =>
      'Crea bozze dalle email di widiba@widiba.it';

  @override
  String get setSearchWindow => 'Finestra di ricerca';

  @override
  String setDaysCount(int count) {
    return '$count giorni';
  }

  @override
  String get setCustom => 'Personalizzato…';

  @override
  String get setDaysToScan => 'Giorni da scansionare';

  @override
  String get setDaysUnit => 'giorni';

  @override
  String setNewDrafts(int count) {
    return '$count nuove transazioni da rivedere';
  }

  @override
  String setUnreadEmails(int count) {
    return '$count email non riconosciute';
  }

  @override
  String get setNoNewTransactions => 'Nessuna nuova transazione';

  @override
  String setEmailSyncFailed(String error) {
    return 'Sincronizzazione email fallita: $error';
  }

  @override
  String get setBankNotificationSync => 'Sincronizzazione notifiche banca';

  @override
  String get setSyncRevolutNotifications => 'Sincronizza notifiche Revolut';

  @override
  String get setSyncRevolutNotificationsSubtitle =>
      'Crea bozze dalle notifiche push di Revolut';

  @override
  String get setNotificationAccess => 'Accesso alle notifiche';

  @override
  String get setNotificationAccessBody =>
      'Per leggere le notifiche di Revolut, Budgetti ha bisogno dell\'accesso alle notifiche di sistema. Aprire le impostazioni?';

  @override
  String get setLater => 'Più tardi';

  @override
  String get setOpenSettings => 'Apri impostazioni';

  @override
  String get setGranted => 'Concesso';

  @override
  String get setNotGranted => 'Non concesso — tocca per aprire le impostazioni';

  @override
  String get setReadNotificationsNow => 'Leggi notifiche ora';

  @override
  String setUnreadNotifications(int count) {
    return '$count notifiche non riconosciute';
  }

  @override
  String get setNoNewRevolutNotifications => 'Nessuna nuova notifica Revolut';

  @override
  String get setNotificationAccessMissing =>
      'Accesso alle notifiche non concesso';

  @override
  String setNotificationReadFailed(String error) {
    return 'Lettura notifiche fallita: $error';
  }

  @override
  String get setImportRevolutStatement => 'Importa estratto conto Revolut';

  @override
  String get setImportRevolutStatementSubtitle =>
      'Da CSV — crea bozze da rivedere, salta i doppioni';

  @override
  String setCountToReview(int count) {
    return '$count da rivedere';
  }

  @override
  String setCountAlreadyPresent(int count) {
    return '$count già presenti';
  }

  @override
  String setCountUnreadableRows(int count) {
    return '$count righe illeggibili';
  }

  @override
  String get setNoTransactionsInFile => 'Nessuna transazione trovata nel file';

  @override
  String get setReview => 'Rivedi';

  @override
  String setStatementImportFailed(String error) {
    return 'Import estratto conto fallito: $error';
  }

  @override
  String get setAutoBackup => 'Backup automatico';

  @override
  String get setAutoBackupToggle => 'Backup automatico';

  @override
  String get setAutoBackupToggleSubtitle =>
      'Backup locale giornaliero (cloud se connesso)';

  @override
  String get setBackupTime => 'Orario backup';

  @override
  String get setBackupFolder => 'Cartella backup';

  @override
  String get setDefaultBackupFolder => 'Predefinita (Interna)';

  @override
  String get setDataManagement => 'Gestione dati';

  @override
  String get setExportBackup => 'Esporta backup (JSON)';

  @override
  String get setExportBackupSubtitle => 'File di backup locale';

  @override
  String get setImportBackup => 'Importa backup (JSON)';

  @override
  String get setImportBackupSubtitle => 'Ripristina da file locale';

  @override
  String get setImportBackupTitle => 'Importa backup';

  @override
  String get setImportBackupBody =>
      'Sostituirà TUTTI i dati attuali. Questa azione non può essere annullata.';

  @override
  String get setImport => 'Importa';

  @override
  String get statsTitle => 'Statistiche';

  @override
  String statsError(String err) {
    return 'Errore: $err';
  }

  @override
  String get statsDistribution => 'Distribuzione';

  @override
  String get statsTrends => 'Andamento';

  @override
  String get statsBreakdown => 'Dettaglio';

  @override
  String get statsLedgerMonthly => 'Registro · Mensile';

  @override
  String get statsCategories => 'Categorie';

  @override
  String get statsNoTagsHint => 'Nessuna spesa con tag in questo periodo.';

  @override
  String get statsNoActivity => 'Nessuna attività';

  @override
  String statsNothingRecorded(String label) {
    return 'Niente registrato per $label.';
  }

  @override
  String get statsTryAnotherPeriod =>
      'Prova un altro periodo dai filtri sopra.';

  @override
  String get statsTrend12Months => 'Tendenza a 12 mesi';

  @override
  String get statsTransactions => 'Transazioni';

  @override
  String statsNoTransactionsIn(String label) {
    return 'Nessuna transazione in $label.';
  }

  @override
  String statsNothingRecordedCategory(String label) {
    return 'Niente registrato per questa categoria in $label.';
  }

  @override
  String get statsScopeExpenses => 'Spese';

  @override
  String get statsScopeIncome => 'Entrate';

  @override
  String get statsMonth => 'Mese';

  @override
  String get statsYear => 'Anno';

  @override
  String get statsTotalSpent => 'Totale speso';

  @override
  String get statsTotalEarned => 'Totale guadagnato';

  @override
  String get statsNetActivity => 'Attività netta';

  @override
  String get statsDailyAvg => 'Media giornaliera';

  @override
  String get statsNetFlow => 'Flusso netto';

  @override
  String get statsPredicted => 'Previsto';

  @override
  String get statsSavings => 'Risparmio';

  @override
  String get statsMonthlyBudget => 'Budget mensile';

  @override
  String statsOver(String amount) {
    return '+$amount oltre';
  }

  @override
  String statsLeft(String amount) {
    return '$amount rimasti';
  }

  @override
  String statsMore(int count) {
    return '+$count altri';
  }

  @override
  String get statsMonthlyAvg => 'Media mensile';

  @override
  String get statsLargest => 'Massimo';

  @override
  String get statsNoTrendData => 'Nessun dato';

  @override
  String get statsEarned => 'Guadagnato';

  @override
  String get statsSpent => 'Speso';

  @override
  String statsPctOf(String pct) {
    return '$pct% sul totale';
  }

  @override
  String get txActivity => 'Attività';

  @override
  String get txAllTime => 'Sempre';

  @override
  String get txAllWallets => 'Tutti i portafogli';

  @override
  String get txAlreadyInAccount => 'Già nel conto';

  @override
  String get txApplyFilters => 'Applica filtri';

  @override
  String get txApprove => 'Approva';

  @override
  String get txBetweenYourWallets => 'Giro tra i tuoi portafogli';

  @override
  String get txCategories => 'Categorie';

  @override
  String get txCredit => 'Accredito';

  @override
  String get txCustom => 'Personalizzato';

  @override
  String get txDateRange => 'Periodo';

  @override
  String txDeleteConfirm(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Vuoi eliminare $count elementi?',
      one: 'Vuoi eliminare 1 elemento?',
    );
    return '$_temp0';
  }

  @override
  String get txDeleteTransactionsTitle => 'Eliminare le transazioni?';

  @override
  String get txDetails => 'Dettagli';

  @override
  String get txDestinationWallet => 'Portafoglio di destinazione';

  @override
  String get txEditExpense => 'Modifica spesa';

  @override
  String get txEditIncome => 'Modifica entrata';

  @override
  String get txEditTransfer => 'Modifica trasferimento';

  @override
  String get txEmail => 'Email';

  @override
  String get txEnterAmount => 'Inserisci l\'importo';

  @override
  String get txEnterDescription => 'Inserisci una descrizione';

  @override
  String txError(String error) {
    return 'Errore: $error';
  }

  @override
  String txErrorLoadingAccounts(String error) {
    return 'Errore nel caricamento dei conti: $error';
  }

  @override
  String txErrorLoadingCategories(String error) {
    return 'Errore nel caricamento delle categorie: $error';
  }

  @override
  String txErrorLoadingTags(String error) {
    return 'Errore nel caricamento dei tag: $error';
  }

  @override
  String get txExternalOutflow => 'Uscita verso esterno';

  @override
  String get txFastCategorization => 'Categorizzazione rapida';

  @override
  String get txFilterByWallet => 'Filtra per portafoglio';

  @override
  String get txFilters => 'Filtri';

  @override
  String get txFrom => 'Da';

  @override
  String get txFromEmail => 'Dall\'email';

  @override
  String get txIgnore => 'Ignora';

  @override
  String get txInstallment => 'Rata';

  @override
  String txInstallmentOption(String amount, int count, int paid) {
    return '$amount × $count · $paid pagate finora';
  }

  @override
  String get txInvalidAmount => 'Non valido';

  @override
  String get txIsSameExpense => 'È la stessa spesa?';

  @override
  String get txLast30Days => 'Ultimi 30 giorni';

  @override
  String get txLast7Days => 'Ultimi 7 giorni';

  @override
  String get txLedger => 'Registro';

  @override
  String get txMovements => 'Movimenti';

  @override
  String get txMovementUndecided => 'Movimento — da decidere';

  @override
  String get txNewExpense => 'Nuova spesa';

  @override
  String get txNewIncome => 'Nuova entrata';

  @override
  String get txNewTransfer => 'Nuovo trasferimento';

  @override
  String get txNoActivity => 'Nessuna attività';

  @override
  String get txNoContent => '(nessun contenuto)';

  @override
  String get txNoDifferent => 'No, è diversa';

  @override
  String get txNoTransactionsPeriod => 'Nessuna transazione in questo periodo';

  @override
  String get txNoTransactionsToReview => 'Nessuna transazione da rivedere';

  @override
  String get txNoWalletSelected => 'Nessun portafoglio selezionato';

  @override
  String get txNotARate => 'Non è una rata';

  @override
  String get txNote => 'Nota';

  @override
  String get txNoteHint => 'Per cosa era?';

  @override
  String get txNotification => 'Notifica';

  @override
  String txOcrError(String error) {
    return 'Errore OCR: $error';
  }

  @override
  String get txPayment => 'Pagamento';

  @override
  String get txPossiblyAlreadyRecorded => 'Forse già registrata';

  @override
  String get txPleaseSelectOtherWallet =>
      'Seleziona un portafoglio di destinazione diverso';

  @override
  String get txPleaseSelectWallet => 'Seleziona un portafoglio';

  @override
  String get txReceiptScanned => 'Ricevuta scansionata';

  @override
  String get txResetAll => 'Azzera tutto';

  @override
  String txReviewBannerCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count transazioni da rivedere',
      one: '1 transazione da rivedere',
    );
    return '$_temp0';
  }

  @override
  String get txReviewInbox => 'Da rivedere';

  @override
  String get txScan => 'Scansiona';

  @override
  String get txSelect => 'Seleziona';

  @override
  String get txSelectCategory => 'Seleziona categoria';

  @override
  String get txSelectDestination => 'Seleziona destinazione';

  @override
  String get txSelectFromAccount => 'Seleziona conto di origine';

  @override
  String get txSelectFromWallet => 'Seleziona portafoglio di origine';

  @override
  String get txSelectSource => 'Seleziona origine';

  @override
  String get txSelectToAccount => 'Seleziona conto di destinazione';

  @override
  String get txSelectToWallet => 'Seleziona portafoglio di destinazione';

  @override
  String get txSelectWallet => 'Seleziona portafoglio';

  @override
  String txSelected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count selezionate',
      one: '1 selezionata',
    );
    return '$_temp0';
  }

  @override
  String get txSepaUndecided => 'Bonifico SEPA — da decidere';

  @override
  String get txSourceWallet => 'Portafoglio di origine';

  @override
  String get txSwipeNext => 'Scorri per la transazione successiva';

  @override
  String get txTo => 'A';

  @override
  String get txTransferDetails => 'Dettagli trasferimento';

  @override
  String get txTransactionAdded => 'Transazione aggiunta';

  @override
  String get txTransactionUpdated => 'Transazione aggiornata';

  @override
  String txUnrecognizedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count email non riconosciute',
      one: '1 email non riconosciuta',
    );
    return '$_temp0';
  }

  @override
  String get txUnrecognizedMessages => 'Messaggi non riconosciuti';

  @override
  String txUnreadableMessage(String kind, String source, String date) {
    return '$kind $source del $date — non sono riuscito a leggerla';
  }

  @override
  String get txUpdate => 'Aggiorna';

  @override
  String get txWhatKindOfTransfer => 'Che tipo di bonifico è?';

  @override
  String get txYesSame => 'Sì, è la stessa';

  @override
  String get txYouReceived => 'Hai ricevuto';

  @override
  String get txYouSpent => 'Hai speso';

  @override
  String get txYouTransferred => 'Hai trasferito';
}
