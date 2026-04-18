import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_am.dart';
import 'app_localizations_ar.dart';
import 'app_localizations_bn.dart';
import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fa.dart';
import 'app_localizations_fil.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_gu.dart';
import 'app_localizations_ha.dart';
import 'app_localizations_hi.dart';
import 'app_localizations_id.dart';
import 'app_localizations_it.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_jv.dart';
import 'app_localizations_kn.dart';
import 'app_localizations_ko.dart';
import 'app_localizations_mr.dart';
import 'app_localizations_ms.dart';
import 'app_localizations_nl.dart';
import 'app_localizations_pa.dart';
import 'app_localizations_pl.dart';
import 'app_localizations_pt.dart';
import 'app_localizations_ru.dart';
import 'app_localizations_sw.dart';
import 'app_localizations_ta.dart';
import 'app_localizations_te.dart';
import 'app_localizations_th.dart';
import 'app_localizations_tr.dart';
import 'app_localizations_uk.dart';
import 'app_localizations_ur.dart';
import 'app_localizations_vi.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('am'),
    Locale('ar'),
    Locale('bn'),
    Locale('de'),
    Locale('en'),
    Locale('es'),
    Locale('fa'),
    Locale('fil'),
    Locale('fr'),
    Locale('gu'),
    Locale('ha'),
    Locale('hi'),
    Locale('id'),
    Locale('it'),
    Locale('ja'),
    Locale('jv'),
    Locale('kn'),
    Locale('ko'),
    Locale('mr'),
    Locale('ms'),
    Locale('nl'),
    Locale('pa'),
    Locale('pl'),
    Locale('pt'),
    Locale('pt', 'BR'),
    Locale('ru'),
    Locale('sw'),
    Locale('ta'),
    Locale('te'),
    Locale('th'),
    Locale('tr'),
    Locale('uk'),
    Locale('ur'),
    Locale('vi'),
    Locale('zh'),
    Locale('zh', 'TW'),
  ];

  /// Application name
  ///
  /// In en, this message translates to:
  /// **'Vetviona'**
  String get appName;

  /// Settings screen title
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// Language settings section title
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageSection;

  /// Appearance settings section title
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearanceSection;

  /// Dark mode toggle label
  ///
  /// In en, this message translates to:
  /// **'Dark Mode'**
  String get darkMode;

  /// Sound settings section title
  ///
  /// In en, this message translates to:
  /// **'Sound'**
  String get soundSection;

  /// Sync settings section title
  ///
  /// In en, this message translates to:
  /// **'RootLoop™ Sync'**
  String get syncSection;

  /// Onboarding welcome title
  ///
  /// In en, this message translates to:
  /// **'Welcome to Vetviona'**
  String get welcomeToVetviona;

  /// Onboarding page 1 title
  ///
  /// In en, this message translates to:
  /// **'Start with yourself'**
  String get onboardingStartTitle;

  /// Onboarding page 2 title
  ///
  /// In en, this message translates to:
  /// **'Link your family'**
  String get onboardingLinkTitle;

  /// Onboarding page 3 title
  ///
  /// In en, this message translates to:
  /// **'Explore your tree'**
  String get onboardingExploreTitle;

  /// Onboarding page 4 title
  ///
  /// In en, this message translates to:
  /// **'Sync with family'**
  String get onboardingSyncTitle;

  /// Onboarding page 1 body
  ///
  /// In en, this message translates to:
  /// **'Works fully offline. Your data stays with you.'**
  String get onboardingStartBody;

  /// Onboarding page 2 body
  ///
  /// In en, this message translates to:
  /// **'Tap the + button on the home screen to add your first family member.'**
  String get onboardingAddBody;

  /// Onboarding page 3 body
  ///
  /// In en, this message translates to:
  /// **'Open any person\'s profile and use \"Add Relationship\" to link them.'**
  String get onboardingLinkBody;

  /// Onboarding page 4 body
  ///
  /// In en, this message translates to:
  /// **'Access diagrams from the side menu or a person\'s profile page.'**
  String get onboardingDiagramsBody;

  /// Onboarding page 5 body
  ///
  /// In en, this message translates to:
  /// **'No internet required. Open Settings → RootLoop™ Sync to get started.'**
  String get onboardingSyncBody;

  /// Skip button label
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// Get started button label
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get getStarted;

  /// Next button label
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// Used in page counter like '2 of 5'
  ///
  /// In en, this message translates to:
  /// **'of'**
  String get pageCounterOf;

  /// Sign in button/title
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get signIn;

  /// Login screen subtitle
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get welcomeBack;

  /// Username field label
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get username;

  /// Password field label
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// Link to register screen
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account?'**
  String get dontHaveAccount;

  /// Register button label
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get register;

  /// Login error message
  ///
  /// In en, this message translates to:
  /// **'Invalid username or password. Please try again.'**
  String get invalidCredentials;

  /// Validation: username required
  ///
  /// In en, this message translates to:
  /// **'Username is required'**
  String get usernameRequired;

  /// Validation: password required
  ///
  /// In en, this message translates to:
  /// **'Password is required'**
  String get passwordRequired;

  /// Create account screen title
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get createAccount;

  /// Create account subtitle
  ///
  /// In en, this message translates to:
  /// **'Create your account'**
  String get createYourAccount;

  /// Optional PIN hint on register screen
  ///
  /// In en, this message translates to:
  /// **'Set an optional local PIN to protect this device.'**
  String get optionalPinHint;

  /// Confirm password field label
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get confirmPassword;

  /// Validation: password too short
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 4 characters'**
  String get passwordMinLength;

  /// Validation: passwords do not match
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get passwordsMismatch;

  /// Link to sign in screen
  ///
  /// In en, this message translates to:
  /// **'Already have an account?'**
  String get alreadyHaveAccount;

  /// Success message after registration
  ///
  /// In en, this message translates to:
  /// **'Account created successfully'**
  String get accountCreated;

  /// Registration error message
  ///
  /// In en, this message translates to:
  /// **'Registration failed. Username may already be taken.'**
  String get registrationFailed;

  /// Family timeline screen title
  ///
  /// In en, this message translates to:
  /// **'Family Timeline'**
  String get familyTimeline;

  /// Search events placeholder
  ///
  /// In en, this message translates to:
  /// **'Search events…'**
  String get searchEvents;

  /// Filter: all events
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get filterAll;

  /// Filter: births
  ///
  /// In en, this message translates to:
  /// **'Births'**
  String get filterBirths;

  /// Filter: deaths
  ///
  /// In en, this message translates to:
  /// **'Deaths'**
  String get filterDeaths;

  /// Filter: partnerships
  ///
  /// In en, this message translates to:
  /// **'Partnerships'**
  String get filterPartnerships;

  /// Filter: events
  ///
  /// In en, this message translates to:
  /// **'Events'**
  String get filterEvents;

  /// Empty state: no events match filter
  ///
  /// In en, this message translates to:
  /// **'No events match.'**
  String get noEventsMatch;

  /// Empty state: no people for timeline
  ///
  /// In en, this message translates to:
  /// **'Add people to see the family timeline.'**
  String get addPeopleForTimeline;

  /// Label for events without a date
  ///
  /// In en, this message translates to:
  /// **'Undated'**
  String get undated;

  /// Event type: birth
  ///
  /// In en, this message translates to:
  /// **'Birth'**
  String get birth;

  /// Event type: death
  ///
  /// In en, this message translates to:
  /// **'Death'**
  String get death;

  /// Event type: partnership ended
  ///
  /// In en, this message translates to:
  /// **'Partnership ended'**
  String get partnershipEnded;

  /// Sources section/screen title
  ///
  /// In en, this message translates to:
  /// **'Sources'**
  String get sources;

  /// Empty state: no sources
  ///
  /// In en, this message translates to:
  /// **'No sources added yet.'**
  String get noSourcesYet;

  /// Add source button label
  ///
  /// In en, this message translates to:
  /// **'Add Source'**
  String get addSource;

  /// Edit citations button label
  ///
  /// In en, this message translates to:
  /// **'Edit Citations'**
  String get editCitations;

  /// Cancel button label
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// Save button label
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// Delete source button label
  ///
  /// In en, this message translates to:
  /// **'Delete Source'**
  String get deleteSource;

  /// Delete button label
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// Citations section label
  ///
  /// In en, this message translates to:
  /// **'Citations'**
  String get citations;

  /// Pedigree chart screen title
  ///
  /// In en, this message translates to:
  /// **'Pedigree Chart'**
  String get pedigreeChart;

  /// Empty state: no persons in tree
  ///
  /// In en, this message translates to:
  /// **'No people in the tree yet.'**
  String get noPersonsYet;

  /// Focus person label in pedigree
  ///
  /// In en, this message translates to:
  /// **'Focus person'**
  String get focusPerson;

  /// Generations label
  ///
  /// In en, this message translates to:
  /// **'generations'**
  String get generations;

  /// Relationship finder screen title
  ///
  /// In en, this message translates to:
  /// **'Relationship Finder'**
  String get relationshipFinder;

  /// From person field label
  ///
  /// In en, this message translates to:
  /// **'From Person'**
  String get fromPerson;

  /// To person field label
  ///
  /// In en, this message translates to:
  /// **'To Person'**
  String get toPerson;

  /// Find relationship button label
  ///
  /// In en, this message translates to:
  /// **'Find Relationship'**
  String get findRelationship;

  /// No relationship path found message
  ///
  /// In en, this message translates to:
  /// **'No relationship path found between these two people.'**
  String get noRelationshipFound;

  /// Path label in relationship finder
  ///
  /// In en, this message translates to:
  /// **'Path'**
  String get path;

  /// Start label
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get start;

  /// End label
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get end;

  /// Relationship: same person
  ///
  /// In en, this message translates to:
  /// **'Same Person'**
  String get samePerson;

  /// Relationship: partner or spouse
  ///
  /// In en, this message translates to:
  /// **'Partner/Spouse'**
  String get partnerSpouse;

  /// Relationship: parent
  ///
  /// In en, this message translates to:
  /// **'Parent'**
  String get parent;

  /// Relationship: grandparent
  ///
  /// In en, this message translates to:
  /// **'Grandparent'**
  String get grandparent;

  /// Relationship: great-grandparent
  ///
  /// In en, this message translates to:
  /// **'Great-Grandparent'**
  String get greatGrandparent;

  /// Relationship: child
  ///
  /// In en, this message translates to:
  /// **'Child'**
  String get child;

  /// Relationship: grandchild
  ///
  /// In en, this message translates to:
  /// **'Grandchild'**
  String get grandchild;

  /// Relationship: great-grandchild
  ///
  /// In en, this message translates to:
  /// **'Great-Grandchild'**
  String get greatGrandchild;

  /// Relationship: sibling
  ///
  /// In en, this message translates to:
  /// **'Sibling'**
  String get sibling;

  /// Relationship: aunt or uncle
  ///
  /// In en, this message translates to:
  /// **'Aunt/Uncle'**
  String get auntUncle;

  /// Relationship: niece or nephew
  ///
  /// In en, this message translates to:
  /// **'Niece/Nephew'**
  String get nieceNephew;

  /// Relationship: cousin
  ///
  /// In en, this message translates to:
  /// **'Cousin'**
  String get cousin;

  /// Relationship modifier: once removed
  ///
  /// In en, this message translates to:
  /// **'once removed'**
  String get onceRemoved;

  /// Relationship modifier: times removed
  ///
  /// In en, this message translates to:
  /// **'times removed'**
  String get timesRemoved;

  /// Generic relationship label
  ///
  /// In en, this message translates to:
  /// **'Relative'**
  String get relative;

  /// Conflict resolver screen title
  ///
  /// In en, this message translates to:
  /// **'Evidence Conflict Resolver'**
  String get conflictResolver;

  /// No conflicts found message
  ///
  /// In en, this message translates to:
  /// **'No conflicting evidence found'**
  String get noConflictsFound;

  /// All conflicts resolved message
  ///
  /// In en, this message translates to:
  /// **'All conflicts resolved'**
  String get allConflictsResolved;

  /// Conflicts resolved count label
  ///
  /// In en, this message translates to:
  /// **'conflicts resolved'**
  String get conflictsResolved;

  /// Resolved label
  ///
  /// In en, this message translates to:
  /// **'Resolved'**
  String get resolved;

  /// Conflict label
  ///
  /// In en, this message translates to:
  /// **'Conflict'**
  String get conflict;

  /// Clear button label
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// Prefer button label
  ///
  /// In en, this message translates to:
  /// **'Prefer'**
  String get prefer;

  /// Calendar screen title
  ///
  /// In en, this message translates to:
  /// **'Birthdays & Anniversaries'**
  String get birthdaysAnniversaries;

  /// No upcoming events message
  ///
  /// In en, this message translates to:
  /// **'No upcoming events'**
  String get noUpcomingEvents;

  /// Hint to add dates for calendar
  ///
  /// In en, this message translates to:
  /// **'Add birth dates to living people or wedding dates to partnerships to see upcoming events here.'**
  String get addDatesHint;

  /// Calendar label: today
  ///
  /// In en, this message translates to:
  /// **'Today!'**
  String get today;

  /// Calendar label: tomorrow
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get tomorrow;

  /// Calendar label: in X days
  ///
  /// In en, this message translates to:
  /// **'In {days} days'**
  String inXDays(int days);

  /// Event type: birthday
  ///
  /// In en, this message translates to:
  /// **'Birthday'**
  String get birthday;

  /// Event type: anniversary
  ///
  /// In en, this message translates to:
  /// **'Anniversary'**
  String get anniversary;

  /// Fan chart screen title
  ///
  /// In en, this message translates to:
  /// **'Fan Chart'**
  String get fanChart;

  /// Fan chart: change root person
  ///
  /// In en, this message translates to:
  /// **'Change root person'**
  String get changeRootPerson;

  /// Family tree screen title
  ///
  /// In en, this message translates to:
  /// **'Family Tree'**
  String get familyTree;

  /// Tree settings label
  ///
  /// In en, this message translates to:
  /// **'Tree Settings'**
  String get treeSettings;

  /// Tree view: interactive
  ///
  /// In en, this message translates to:
  /// **'Interactive'**
  String get interactive;

  /// Tree view: ancestry
  ///
  /// In en, this message translates to:
  /// **'Ancestry'**
  String get ancestry;

  /// Tree view: descendancy
  ///
  /// In en, this message translates to:
  /// **'Descendancy'**
  String get descendancy;

  /// Tree view: pedigree
  ///
  /// In en, this message translates to:
  /// **'Pedigree'**
  String get pedigree;

  /// Layout label
  ///
  /// In en, this message translates to:
  /// **'Layout:'**
  String get layout;

  /// Timeline screen title
  ///
  /// In en, this message translates to:
  /// **'Timeline'**
  String get timeline;

  /// Empty state: no events for person
  ///
  /// In en, this message translates to:
  /// **'No events recorded for this person.'**
  String get noEventsForPerson;

  /// License verification screen title
  ///
  /// In en, this message translates to:
  /// **'Verify Paid License'**
  String get verifyLicense;

  /// Email field label on license verification
  ///
  /// In en, this message translates to:
  /// **'Vetviona account email'**
  String get vetvionaEmail;

  /// Validation: email required
  ///
  /// In en, this message translates to:
  /// **'Email is required.'**
  String get emailRequired;

  /// Validation: enter valid email
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email.'**
  String get enterValidEmail;

  /// Verify license button label
  ///
  /// In en, this message translates to:
  /// **'Verify license'**
  String get verifyLicenseButton;

  /// Link to claim gift license
  ///
  /// In en, this message translates to:
  /// **'Received a license gift? Claim it'**
  String get receivedGiftClaim;

  /// Claim gift license screen title
  ///
  /// In en, this message translates to:
  /// **'Claim a License Gift'**
  String get claimGiftTitle;

  /// License gift received message
  ///
  /// In en, this message translates to:
  /// **'You received a license!'**
  String get youReceivedLicense;

  /// Claim gift license instructions
  ///
  /// In en, this message translates to:
  /// **'Follow the steps below to add it to your Vetviona account.'**
  String get claimGiftSteps;

  /// Step: download app
  ///
  /// In en, this message translates to:
  /// **'Download the Vetviona app'**
  String get downloadApp;

  /// Step: enter claim token
  ///
  /// In en, this message translates to:
  /// **'Enter your claim token'**
  String get enterClaimToken;

  /// Claim token field label
  ///
  /// In en, this message translates to:
  /// **'Claim token'**
  String get claimToken;

  /// Validation: claim token required
  ///
  /// In en, this message translates to:
  /// **'Please enter a claim token.'**
  String get enterClaimTokenHint;

  /// Claim license button label
  ///
  /// In en, this message translates to:
  /// **'Claim License'**
  String get claimLicense;

  /// FAQ link label
  ///
  /// In en, this message translates to:
  /// **'Frequently asked questions'**
  String get faq;

  /// Sign in / verify license link label
  ///
  /// In en, this message translates to:
  /// **'Sign In / Verify License'**
  String get signInVerify;

  /// Name field label
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// Person name field hint
  ///
  /// In en, this message translates to:
  /// **'Enter person name'**
  String get enterPersonName;

  /// Gender field label
  ///
  /// In en, this message translates to:
  /// **'Gender (optional)'**
  String get genderOptional;

  /// Gender: not specified
  ///
  /// In en, this message translates to:
  /// **'Not specified'**
  String get notSpecified;

  /// Gender: male
  ///
  /// In en, this message translates to:
  /// **'Male'**
  String get male;

  /// Gender: female
  ///
  /// In en, this message translates to:
  /// **'Female'**
  String get female;

  /// Gender: non-binary
  ///
  /// In en, this message translates to:
  /// **'Non-binary'**
  String get nonBinary;

  /// Gender: other
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get other;

  /// Add button label
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// Tree settings: layout style
  ///
  /// In en, this message translates to:
  /// **'Layout Style'**
  String get layoutStyle;

  /// Tree settings: generations to show
  ///
  /// In en, this message translates to:
  /// **'Generations to show'**
  String get generationsToShow;

  /// Tree settings: ancestors
  ///
  /// In en, this message translates to:
  /// **'Ancestors'**
  String get ancestors;

  /// Tree settings: descendants
  ///
  /// In en, this message translates to:
  /// **'Descendants'**
  String get descendants;

  /// Tree settings: canvas layout
  ///
  /// In en, this message translates to:
  /// **'Canvas'**
  String get canvas;

  /// Tree settings: show add slots
  ///
  /// In en, this message translates to:
  /// **'Show \"Add…\" placeholder slots'**
  String get showAddSlots;

  /// Tree settings: quick add buttons
  ///
  /// In en, this message translates to:
  /// **'Quick-add buttons for missing relatives'**
  String get quickAddButtons;

  /// Tree settings: add-slot tiers
  ///
  /// In en, this message translates to:
  /// **'Add-slot tiers'**
  String get addSlotTiers;

  /// Photo gallery: image not available
  ///
  /// In en, this message translates to:
  /// **'Image not available'**
  String get imageNotAvailable;

  /// Source detail screen title
  ///
  /// In en, this message translates to:
  /// **'Source Details'**
  String get sourceDetails;

  /// Source title field label
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get title;

  /// Source type field label
  ///
  /// In en, this message translates to:
  /// **'Source Type'**
  String get sourceType;

  /// URL field label
  ///
  /// In en, this message translates to:
  /// **'URL (optional)'**
  String get urlOptional;

  /// Author field label
  ///
  /// In en, this message translates to:
  /// **'Author (optional)'**
  String get authorOptional;

  /// Publisher field label
  ///
  /// In en, this message translates to:
  /// **'Publisher (optional)'**
  String get publisherOptional;

  /// Publication date field label
  ///
  /// In en, this message translates to:
  /// **'Publication Date (optional)'**
  String get publicationDateOptional;

  /// Repository field label
  ///
  /// In en, this message translates to:
  /// **'Repository / Archive (optional)'**
  String get repositoryOptional;

  /// Volume/page field label
  ///
  /// In en, this message translates to:
  /// **'Volume / Page (optional)'**
  String get volumePageOptional;

  /// URL retrieval date field label
  ///
  /// In en, this message translates to:
  /// **'URL Retrieval Date (optional)'**
  String get retrievalDateOptional;

  /// Confidence rating field label
  ///
  /// In en, this message translates to:
  /// **'Confidence Rating (optional)'**
  String get confidenceOptional;

  /// Confidence: not rated
  ///
  /// In en, this message translates to:
  /// **'Not rated'**
  String get notRated;

  /// Save source button label
  ///
  /// In en, this message translates to:
  /// **'Save Source'**
  String get saveSource;

  /// Validation: title required
  ///
  /// In en, this message translates to:
  /// **'Title is required'**
  String get titleRequired;

  /// Validation: select type required
  ///
  /// In en, this message translates to:
  /// **'Please select a type'**
  String get selectTypeRequired;

  /// Relationship certificate screen title
  ///
  /// In en, this message translates to:
  /// **'Relationship Certificate'**
  String get relationshipCertificate;

  /// Generate certificate button label
  ///
  /// In en, this message translates to:
  /// **'Generate Certificate'**
  String get generateCertificate;

  /// Certificate preview label
  ///
  /// In en, this message translates to:
  /// **'Certificate Preview'**
  String get certificatePreview;

  /// Export as text file button label
  ///
  /// In en, this message translates to:
  /// **'Export as text file'**
  String get exportAsText;

  /// Person A field label
  ///
  /// In en, this message translates to:
  /// **'Person A (subject)'**
  String get personA;

  /// Person B field label
  ///
  /// In en, this message translates to:
  /// **'Person B (ancestor / relative)'**
  String get personB;

  /// Export button label
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get export;

  /// Place picker screen title
  ///
  /// In en, this message translates to:
  /// **'Pick a Place'**
  String get pickAPlace;

  /// Empty state: no places match
  ///
  /// In en, this message translates to:
  /// **'No places match your search.'**
  String get noPlacesMatch;

  /// Global city database label
  ///
  /// In en, this message translates to:
  /// **'Global city database'**
  String get globalCityDatabase;

  /// Search places placeholder
  ///
  /// In en, this message translates to:
  /// **'Search places…'**
  String get searchPlaces;

  /// Confirm button label
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// Map picker search placeholder
  ///
  /// In en, this message translates to:
  /// **'Search for a place…'**
  String get searchForPlace;

  /// Map picker instruction
  ///
  /// In en, this message translates to:
  /// **'Tap anywhere on the map to place a pin'**
  String get tapToPlacePin;

  /// Use this location button label
  ///
  /// In en, this message translates to:
  /// **'Use this location'**
  String get useThisLocation;

  /// Map layer: political boundaries
  ///
  /// In en, this message translates to:
  /// **'Political boundaries'**
  String get politicalBoundaries;

  /// Map info: postal code
  ///
  /// In en, this message translates to:
  /// **'Postal code'**
  String get postalCode;

  /// Map info: country code
  ///
  /// In en, this message translates to:
  /// **'Country code'**
  String get countryCode;

  /// Tree screen: list view
  ///
  /// In en, this message translates to:
  /// **'List view'**
  String get listView;

  /// Tree screen: table view
  ///
  /// In en, this message translates to:
  /// **'Table view'**
  String get tableView;

  /// Tree screen: view diagram
  ///
  /// In en, this message translates to:
  /// **'View Diagram'**
  String get viewDiagram;

  /// Add person button label
  ///
  /// In en, this message translates to:
  /// **'Add Person'**
  String get addPerson;

  /// Quick add person button label
  ///
  /// In en, this message translates to:
  /// **'Quick add person'**
  String get quickAddPerson;

  /// Quick add person hint
  ///
  /// In en, this message translates to:
  /// **'Create someone with just a name'**
  String get createSomeoneWithName;

  /// Quick add label
  ///
  /// In en, this message translates to:
  /// **'Quick Add'**
  String get quickAdd;

  /// View interactive tree button
  ///
  /// In en, this message translates to:
  /// **'View interactive tree diagram'**
  String get viewInteractiveTree;

  /// Empty state: no persons
  ///
  /// In en, this message translates to:
  /// **'No people in this tree yet'**
  String get noPersonsInTree;

  /// Empty state hint
  ///
  /// In en, this message translates to:
  /// **'Add your first family member to get started.'**
  String get addFirstMember;

  /// Add first person button label
  ///
  /// In en, this message translates to:
  /// **'Add First Person'**
  String get addFirstPerson;

  /// Quick add person dialog title
  ///
  /// In en, this message translates to:
  /// **'Quick Add Person'**
  String get quickAddPersonTitle;

  /// Quick add person dialog subtitle
  ///
  /// In en, this message translates to:
  /// **'Create a person now and fill full details later.'**
  String get createPersonFillLater;

  /// Born label
  ///
  /// In en, this message translates to:
  /// **'Born'**
  String get born;

  /// Died label
  ///
  /// In en, this message translates to:
  /// **'Died'**
  String get died;

  /// Parents label
  ///
  /// In en, this message translates to:
  /// **'Parents'**
  String get parents;

  /// Partners label
  ///
  /// In en, this message translates to:
  /// **'Partners'**
  String get partners;

  /// Children label
  ///
  /// In en, this message translates to:
  /// **'Children'**
  String get children;

  /// Relationships label
  ///
  /// In en, this message translates to:
  /// **'Relationships'**
  String get relationships;

  /// Edit button label
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// Deleted status label
  ///
  /// In en, this message translates to:
  /// **'deleted'**
  String get deleted;

  /// Undo button label
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undo;

  /// Splash screen tagline
  ///
  /// In en, this message translates to:
  /// **'Your family story'**
  String get yourFamilyStory;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
    'am',
    'ar',
    'bn',
    'de',
    'en',
    'es',
    'fa',
    'fil',
    'fr',
    'gu',
    'ha',
    'hi',
    'id',
    'it',
    'ja',
    'jv',
    'kn',
    'ko',
    'mr',
    'ms',
    'nl',
    'pa',
    'pl',
    'pt',
    'ru',
    'sw',
    'ta',
    'te',
    'th',
    'tr',
    'uk',
    'ur',
    'vi',
    'zh',
  ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when language+country codes are specified.
  switch (locale.languageCode) {
    case 'pt':
      {
        switch (locale.countryCode) {
          case 'BR':
            return AppLocalizationsPtBr();
        }
        break;
      }
    case 'zh':
      {
        switch (locale.countryCode) {
          case 'TW':
            return AppLocalizationsZhTw();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'am':
      return AppLocalizationsAm();
    case 'ar':
      return AppLocalizationsAr();
    case 'bn':
      return AppLocalizationsBn();
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fa':
      return AppLocalizationsFa();
    case 'fil':
      return AppLocalizationsFil();
    case 'fr':
      return AppLocalizationsFr();
    case 'gu':
      return AppLocalizationsGu();
    case 'ha':
      return AppLocalizationsHa();
    case 'hi':
      return AppLocalizationsHi();
    case 'id':
      return AppLocalizationsId();
    case 'it':
      return AppLocalizationsIt();
    case 'ja':
      return AppLocalizationsJa();
    case 'jv':
      return AppLocalizationsJv();
    case 'kn':
      return AppLocalizationsKn();
    case 'ko':
      return AppLocalizationsKo();
    case 'mr':
      return AppLocalizationsMr();
    case 'ms':
      return AppLocalizationsMs();
    case 'nl':
      return AppLocalizationsNl();
    case 'pa':
      return AppLocalizationsPa();
    case 'pl':
      return AppLocalizationsPl();
    case 'pt':
      return AppLocalizationsPt();
    case 'ru':
      return AppLocalizationsRu();
    case 'sw':
      return AppLocalizationsSw();
    case 'ta':
      return AppLocalizationsTa();
    case 'te':
      return AppLocalizationsTe();
    case 'th':
      return AppLocalizationsTh();
    case 'tr':
      return AppLocalizationsTr();
    case 'uk':
      return AppLocalizationsUk();
    case 'ur':
      return AppLocalizationsUr();
    case 'vi':
      return AppLocalizationsVi();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
