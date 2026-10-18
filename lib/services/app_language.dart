import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppLanguageController extends GetxController {
  final language = 'en'.obs;

  @override
  void onInit() {
    super.onInit();
    _load();
  }

  Future<void> _load() async {
    final preferences = await SharedPreferences.getInstance();
    language.value = preferences.getString('app_language') ?? 'en';
  }

  Future<void> setLanguage(String value) async {
    language.value = value;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString('app_language', value);
  }
}

class T {
  static const _translations = <String, Map<String, String>>{
    'hi': {
      'Unable to continue': 'जारी नहीं रख सकते',
      'Set up your dairy': 'अपनी डेयरी सेट करें',
      'Welcome back': 'वापसी पर स्वागत है',
      'Dairy name': 'डेयरी का नाम',
      'Email address': 'ईमेल पता',
      'Password': 'पासवर्ड',
      'Show password': 'पासवर्ड दिखाएं',
      'Hide password': 'पासवर्ड छिपाएं',
      'Create account': 'खाता बनाएं',
      'Log in': 'लॉग इन',
      'Already have an account? Log in': 'पहले से खाता है? लॉग इन करें',
      'New to Dairy Desk? Create an account': 'नए हैं? खाता बनाएं',
      'Settings': 'सेटिंग्स',
      'Customers': 'ग्राहक',
      'Refresh customers': 'ग्राहक रीफ्रेश करें',
      'Log out': 'लॉग आउट',
      'Your dairy at a glance': 'आपकी डेयरी एक नज़र में',
      'Search by name or customer number': 'नाम या ग्राहक नंबर से खोजें',
      'Add customer': 'ग्राहक जोड़ें',
      'Add liters': 'लीटर जोड़ें',
      'Edit customer': 'ग्राहक संपादित करें',
      'Customer details': 'ग्राहक विवरण',
      'Customer no.': 'ग्राहक नंबर',
      'Contact': 'संपर्क',
      'Phone number': 'फ़ोन नंबर',
      'Notification channel': 'सूचना माध्यम',
      'Milk defaults': 'दूध की डिफ़ॉल्ट जानकारी',
      'Daily liters': 'दैनिक लीटर',
      'Price per liter': 'प्रति लीटर कीमत',
      'Recent milk entries': 'हाल की दूध प्रविष्टियां',
      'Could not load milk history.': 'दूध का इतिहास लोड नहीं हो सका।',
      'Try again': 'फिर कोशिश करें',
      'No milk entries yet.': 'अभी कोई दूध प्रविष्टि नहीं है।',
      'Could not load customers': 'ग्राहक लोड नहीं हो सके',
      'Check your connection and try again.':
          'कनेक्शन जांचें और फिर कोशिश करें।',
      'No customers found': 'कोई ग्राहक नहीं मिला',
      'No customers yet': 'अभी कोई ग्राहक नहीं है',
      'Try another name or number': 'दूसरा नाम या नंबर आज़माएं',
      'Add your first customer to get started':
          'शुरू करने के लिए पहला ग्राहक जोड़ें',
      'Customer defaults': 'ग्राहक डिफ़ॉल्ट',
      'Default milk & price': 'डिफ़ॉल्ट दूध और कीमत',
      'These values are filled automatically when you add a customer. You can change them for any individual customer.': 'ग्राहक जोड़ते समय ये मान अपने आप भरेंगे। आप इन्हें हर ग्राहक के लिए बदल सकते हैं।',
      'Default liters': 'डिफ़ॉल्ट लीटर',
      'Default price per liter': 'प्रति लीटर डिफ़ॉल्ट कीमत',
      'Save defaults': 'डिफ़ॉल्ट सहेजें',
      'Keep your collection records organized.':
          'अपने संग्रह रिकॉर्ड व्यवस्थित रखें।',
      'Full name': 'पूरा नाम',
      'Liters': 'लीटर',
      'Price': 'कीमत',
      'Customer phone number': 'ग्राहक का फ़ोन नंबर',
      'Send daily message using': 'दैनिक संदेश भेजने का माध्यम',
      'WhatsApp': 'व्हाट्सऐप',
      'SMS / Messages': 'SMS / संदेश',
      'Save customer': 'ग्राहक सहेजें',
      'Message channel': 'संदेश माध्यम',
      'Save changes': 'बदलाव सहेजें',
      'Language': 'भाषा',
      'English': 'अंग्रेज़ी',
      'Hindi': 'हिंदी',
      'Gujarati': 'गुजराती',
      'App language': 'ऐप की भाषा',
      'Cancel': 'रद्द करें',
      'Add today’s milk': 'आज का दूध जोड़ें',
      'Save entry': 'प्रविष्टि सहेजें',
      'Milk entry saved': 'दूध प्रविष्टि सहेजी गई',
      'Required': 'आवश्यक',
      'Enter a valid number': 'मान्य संख्या दर्ज करें',
      'Enter a valid email': 'मान्य ईमेल दर्ज करें',
      'Use at least 8 characters': 'कम से कम 8 अक्षर इस्तेमाल करें',
    },
    'gu': {
      'Unable to continue': 'આગળ વધી શકાતું નથી',
      'Set up your dairy': 'તમારી ડેરી સેટ કરો',
      'Welcome back': 'ફરી સ્વાગત છે',
      'Dairy name': 'ડેરીનું નામ',
      'Email address': 'ઇમેઇલ સરનામું',
      'Password': 'પાસવર્ડ',
      'Show password': 'પાસવર્ડ બતાવો',
      'Hide password': 'પાસવર્ડ છુપાવો',
      'Create account': 'ખાતું બનાવો',
      'Log in': 'લૉગ ઇન',
      'Already have an account? Log in': 'ખાતું છે? લૉગ ઇન કરો',
      'New to Dairy Desk? Create an account': 'નવા છો? ખાતું બનાવો',
      'Settings': 'સેટિંગ્સ',
      'Customers': 'ગ્રાહકો',
      'Refresh customers': 'ગ્રાહકો રિફ્રેશ કરો',
      'Log out': 'લૉગ આઉટ',
      'Your dairy at a glance': 'તમારી ડેરી એક નજરમાં',
      'Search by name or customer number': 'નામ અથવા ગ્રાહક નંબરથી શોધો',
      'Add customer': 'ગ્રાહક ઉમેરો',
      'Add liters': 'લીટર ઉમેરો',
      'Edit customer': 'ગ્રાહક સંપાદિત કરો',
      'Customer no.': 'ગ્રાહક નંબર',
      'Contact': 'સંપર્ક',
      'Phone number': 'ફોન નંબર',
      'Notification channel': 'સૂચના માધ્યમ',
      'Milk defaults': 'દૂધની ડિફૉલ્ટ માહિતી',
      'Daily liters': 'દૈનિક લીટર',
      'Price per liter': 'પ્રતિ લીટર કિંમત',
      'Recent milk entries': 'તાજેતરની દૂધની એન્ટ્રીઓ',
      'Could not load milk history.': 'દૂધનો ઇતિહાસ લોડ થઈ શક્યો નથી.',
      'Try again': 'ફરી પ્રયાસ કરો',
      'No milk entries yet.': 'હજી કોઈ દૂધની એન્ટ્રી નથી.',
      'Could not load customers': 'ગ્રાહકો લોડ થઈ શક્યા નથી',
      'Check your connection and try again.':
          'કનેક્શન તપાસો અને ફરી પ્રયાસ કરો.',
      'No customers found': 'કોઈ ગ્રાહક મળ્યો નથી',
      'No customers yet': 'હજી કોઈ ગ્રાહક નથી',
      'Try another name or number': 'બીજું નામ અથવા નંબર અજમાવો',
      'Add your first customer to get started':
          'શરૂ કરવા માટે પહેલો ગ્રાહક ઉમેરો',
      'Customer defaults': 'ગ્રાહક ડિફૉલ્ટ',
      'Default milk & price': 'ડિફૉલ્ટ દૂધ અને કિંમત',
      'Default liters': 'ડિફૉલ્ટ લીટર',
      'Default price per liter': 'પ્રતિ લીટર ડિફૉલ્ટ કિંમત',
      'Save defaults': 'ડિફૉલ્ટ સંગ્રહો',
      'Customer details': 'ગ્રાહકની વિગતો',
      'Keep your collection records organized.':
          'તમારા સંગ્રહ રેકોર્ડ વ્યવસ્થિત રાખો.',
      'Full name': 'પૂરું નામ',
      'Liters': 'લીટર',
      'Price': 'કિંમત',
      'Customer phone number': 'ગ્રાહકનો ફોન નંબર',
      'Send daily message using': 'દૈનિક સંદેશ મોકલવાનું માધ્યમ',
      'WhatsApp': 'વોટ્સએપ',
      'SMS / Messages': 'SMS / સંદેશાઓ',
      'Save customer': 'ગ્રાહક સંગ્રહો',
      'Message channel': 'સંદેશ માધ્યમ',
      'Save changes': 'ફેરફારો સંગ્રહો',
      'Language': 'ભાષા',
      'English': 'અંગ્રેજી',
      'Hindi': 'હિન્દી',
      'Gujarati': 'ગુજરાતી',
      'App language': 'એપની ભાષા',
      'Cancel': 'રદ કરો',
      'Add today’s milk': 'આજનું દૂધ ઉમેરો',
      'Save entry': 'એન્ટ્રી સાચવો',
      'Milk entry saved': 'દૂધની એન્ટ્રી સંગ્રહાઈ',
      'Required': 'જરૂરી',
      'Enter a valid number': 'માન્ય નંબર દાખલ કરો',
      'Enter a valid email': 'માન્ય ઇમેઇલ દાખલ કરો',
      'Use at least 8 characters': 'ઓછામાં ઓછા 8 અક્ષરોનો ઉપયોગ કરો',
    },
  };

  static String t(String text) {
    final controller = Get.isRegistered<AppLanguageController>()
        ? Get.find<AppLanguageController>()
        : null;
    return _translations[controller?.language.value]?[text] ?? text;
  }
}
