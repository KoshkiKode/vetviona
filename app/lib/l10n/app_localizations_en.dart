// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Vetviona';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get languageSection => 'Language';

  @override
  String get appearanceSection => 'Appearance';

  @override
  String get darkMode => 'Dark Mode';

  @override
  String get soundSection => 'Sound';

  @override
  String get syncSection => 'RootLoop™ Sync';

  @override
  String get welcomeToVetviona => 'Welcome to Vetviona';

  @override
  String get onboardingStartTitle => 'Start with yourself';

  @override
  String get onboardingLinkTitle => 'Link your family';

  @override
  String get onboardingExploreTitle => 'Explore your tree';

  @override
  String get onboardingSyncTitle => 'Sync with family';

  @override
  String get onboardingStartBody =>
      'Works fully offline. Your data stays with you.';

  @override
  String get onboardingAddBody =>
      'Tap the + button on the home screen to add your first family member.';

  @override
  String get onboardingLinkBody =>
      'Open any person\'s profile and use \"Add Relationship\" to link them.';

  @override
  String get onboardingDiagramsBody =>
      'Access diagrams from the side menu or a person\'s profile page.';

  @override
  String get onboardingSyncBody =>
      'No internet required. Open Settings → RootLoop™ Sync to get started.';

  @override
  String get skip => 'Skip';

  @override
  String get getStarted => 'Get Started';

  @override
  String get next => 'Next';

  @override
  String get pageCounterOf => 'of';

  @override
  String get signIn => 'Sign In';

  @override
  String get welcomeBack => 'Welcome back';

  @override
  String get username => 'Username';

  @override
  String get password => 'Password';

  @override
  String get dontHaveAccount => 'Don\'t have an account?';

  @override
  String get register => 'Register';

  @override
  String get invalidCredentials =>
      'Invalid username or password. Please try again.';

  @override
  String get usernameRequired => 'Username is required';

  @override
  String get passwordRequired => 'Password is required';

  @override
  String get createAccount => 'Create Account';

  @override
  String get createYourAccount => 'Create your account';

  @override
  String get optionalPinHint =>
      'Set an optional local PIN to protect this device.';

  @override
  String get confirmPassword => 'Confirm Password';

  @override
  String get passwordMinLength => 'Password must be at least 4 characters';

  @override
  String get passwordsMismatch => 'Passwords do not match';

  @override
  String get alreadyHaveAccount => 'Already have an account?';

  @override
  String get accountCreated => 'Account created successfully';

  @override
  String get registrationFailed =>
      'Registration failed. Username may already be taken.';

  @override
  String get familyTimeline => 'Family Timeline';

  @override
  String get searchEvents => 'Search events…';

  @override
  String get filterAll => 'All';

  @override
  String get filterBirths => 'Births';

  @override
  String get filterDeaths => 'Deaths';

  @override
  String get filterPartnerships => 'Partnerships';

  @override
  String get filterEvents => 'Events';

  @override
  String get noEventsMatch => 'No events match.';

  @override
  String get addPeopleForTimeline => 'Add people to see the family timeline.';

  @override
  String get undated => 'Undated';

  @override
  String get birth => 'Birth';

  @override
  String get death => 'Death';

  @override
  String get partnershipEnded => 'Partnership ended';

  @override
  String get sources => 'Sources';

  @override
  String get noSourcesYet => 'No sources added yet.';

  @override
  String get addSource => 'Add Source';

  @override
  String get editCitations => 'Edit Citations';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get deleteSource => 'Delete Source';

  @override
  String get delete => 'Delete';

  @override
  String get citations => 'Citations';

  @override
  String get pedigreeChart => 'Pedigree Chart';

  @override
  String get noPersonsYet => 'No people in the tree yet.';

  @override
  String get focusPerson => 'Focus person';

  @override
  String get generations => 'generations';

  @override
  String get relationshipFinder => 'Relationship Finder';

  @override
  String get fromPerson => 'From Person';

  @override
  String get toPerson => 'To Person';

  @override
  String get findRelationship => 'Find Relationship';

  @override
  String get noRelationshipFound =>
      'No relationship path found between these two people.';

  @override
  String get path => 'Path';

  @override
  String get start => 'Start';

  @override
  String get end => 'End';

  @override
  String get samePerson => 'Same Person';

  @override
  String get partnerSpouse => 'Partner/Spouse';

  @override
  String get parent => 'Parent';

  @override
  String get grandparent => 'Grandparent';

  @override
  String get greatGrandparent => 'Great-Grandparent';

  @override
  String get child => 'Child';

  @override
  String get grandchild => 'Grandchild';

  @override
  String get greatGrandchild => 'Great-Grandchild';

  @override
  String get sibling => 'Sibling';

  @override
  String get auntUncle => 'Aunt/Uncle';

  @override
  String get nieceNephew => 'Niece/Nephew';

  @override
  String get cousin => 'Cousin';

  @override
  String get onceRemoved => 'once removed';

  @override
  String get timesRemoved => 'times removed';

  @override
  String get relative => 'Relative';

  @override
  String get conflictResolver => 'Evidence Conflict Resolver';

  @override
  String get noConflictsFound => 'No conflicting evidence found';

  @override
  String get allConflictsResolved => 'All conflicts resolved';

  @override
  String get conflictsResolved => 'conflicts resolved';

  @override
  String get resolved => 'Resolved';

  @override
  String get conflict => 'Conflict';

  @override
  String get clear => 'Clear';

  @override
  String get prefer => 'Prefer';

  @override
  String get birthdaysAnniversaries => 'Birthdays & Anniversaries';

  @override
  String get noUpcomingEvents => 'No upcoming events';

  @override
  String get addDatesHint =>
      'Add birth dates to living people or wedding dates to partnerships to see upcoming events here.';

  @override
  String get today => 'Today!';

  @override
  String get tomorrow => 'Tomorrow';

  @override
  String inXDays(int days) {
    return 'In $days days';
  }

  @override
  String get birthday => 'Birthday';

  @override
  String get anniversary => 'Anniversary';

  @override
  String get fanChart => 'Fan Chart';

  @override
  String get changeRootPerson => 'Change root person';

  @override
  String get familyTree => 'Family Tree';

  @override
  String get treeSettings => 'Tree Settings';

  @override
  String get interactive => 'Interactive';

  @override
  String get ancestry => 'Ancestry';

  @override
  String get descendancy => 'Descendancy';

  @override
  String get pedigree => 'Pedigree';

  @override
  String get layout => 'Layout:';

  @override
  String get timeline => 'Timeline';

  @override
  String get noEventsForPerson => 'No events recorded for this person.';

  @override
  String get verifyLicense => 'Verify Paid License';

  @override
  String get vetvionaEmail => 'Vetviona account email';

  @override
  String get emailRequired => 'Email is required.';

  @override
  String get enterValidEmail => 'Enter a valid email.';

  @override
  String get verifyLicenseButton => 'Verify license';

  @override
  String get receivedGiftClaim => 'Received a license gift? Claim it';

  @override
  String get claimGiftTitle => 'Claim a License Gift';

  @override
  String get youReceivedLicense => 'You received a license!';

  @override
  String get claimGiftSteps =>
      'Follow the steps below to add it to your Vetviona account.';

  @override
  String get downloadApp => 'Download the Vetviona app';

  @override
  String get enterClaimToken => 'Enter your claim token';

  @override
  String get claimToken => 'Claim token';

  @override
  String get enterClaimTokenHint => 'Please enter a claim token.';

  @override
  String get claimLicense => 'Claim License';

  @override
  String get faq => 'Frequently asked questions';

  @override
  String get signInVerify => 'Sign In / Verify License';

  @override
  String get name => 'Name';

  @override
  String get enterPersonName => 'Enter person name';

  @override
  String get genderOptional => 'Gender (optional)';

  @override
  String get notSpecified => 'Not specified';

  @override
  String get male => 'Male';

  @override
  String get female => 'Female';

  @override
  String get nonBinary => 'Non-binary';

  @override
  String get other => 'Other';

  @override
  String get add => 'Add';

  @override
  String get layoutStyle => 'Layout Style';

  @override
  String get generationsToShow => 'Generations to show';

  @override
  String get ancestors => 'Ancestors';

  @override
  String get descendants => 'Descendants';

  @override
  String get canvas => 'Canvas';

  @override
  String get showAddSlots => 'Show \"Add…\" placeholder slots';

  @override
  String get quickAddButtons => 'Quick-add buttons for missing relatives';

  @override
  String get addSlotTiers => 'Add-slot tiers';

  @override
  String get imageNotAvailable => 'Image not available';

  @override
  String get sourceDetails => 'Source Details';

  @override
  String get title => 'Title';

  @override
  String get sourceType => 'Source Type';

  @override
  String get urlOptional => 'URL (optional)';

  @override
  String get authorOptional => 'Author (optional)';

  @override
  String get publisherOptional => 'Publisher (optional)';

  @override
  String get publicationDateOptional => 'Publication Date (optional)';

  @override
  String get repositoryOptional => 'Repository / Archive (optional)';

  @override
  String get volumePageOptional => 'Volume / Page (optional)';

  @override
  String get retrievalDateOptional => 'URL Retrieval Date (optional)';

  @override
  String get confidenceOptional => 'Confidence Rating (optional)';

  @override
  String get notRated => 'Not rated';

  @override
  String get saveSource => 'Save Source';

  @override
  String get titleRequired => 'Title is required';

  @override
  String get selectTypeRequired => 'Please select a type';

  @override
  String get relationshipCertificate => 'Relationship Certificate';

  @override
  String get generateCertificate => 'Generate Certificate';

  @override
  String get certificatePreview => 'Certificate Preview';

  @override
  String get exportAsText => 'Export as text file';

  @override
  String get personA => 'Person A (subject)';

  @override
  String get personB => 'Person B (ancestor / relative)';

  @override
  String get export => 'Export';

  @override
  String get pickAPlace => 'Pick a Place';

  @override
  String get noPlacesMatch => 'No places match your search.';

  @override
  String get globalCityDatabase => 'Global city database';

  @override
  String get searchPlaces => 'Search places…';

  @override
  String get confirm => 'Confirm';

  @override
  String get searchForPlace => 'Search for a place…';

  @override
  String get tapToPlacePin => 'Tap anywhere on the map to place a pin';

  @override
  String get useThisLocation => 'Use this location';

  @override
  String get politicalBoundaries => 'Political boundaries';

  @override
  String get postalCode => 'Postal code';

  @override
  String get countryCode => 'Country code';

  @override
  String get listView => 'List view';

  @override
  String get tableView => 'Table view';

  @override
  String get viewDiagram => 'View Diagram';

  @override
  String get addPerson => 'Add Person';

  @override
  String get quickAddPerson => 'Quick add person';

  @override
  String get createSomeoneWithName => 'Create someone with just a name';

  @override
  String get quickAdd => 'Quick Add';

  @override
  String get viewInteractiveTree => 'View interactive tree diagram';

  @override
  String get noPersonsInTree => 'No people in this tree yet';

  @override
  String get addFirstMember => 'Add your first family member to get started.';

  @override
  String get addFirstPerson => 'Add First Person';

  @override
  String get quickAddPersonTitle => 'Quick Add Person';

  @override
  String get createPersonFillLater =>
      'Create a person now and fill full details later.';

  @override
  String get born => 'Born';

  @override
  String get died => 'Died';

  @override
  String get parents => 'Parents';

  @override
  String get partners => 'Partners';

  @override
  String get children => 'Children';

  @override
  String get relationships => 'Relationships';

  @override
  String get edit => 'Edit';

  @override
  String get deleted => 'deleted';

  @override
  String get undo => 'Undo';

  @override
  String get yourFamilyStory => 'Your family story';
}
