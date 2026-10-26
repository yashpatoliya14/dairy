import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('notoSansGujarati is available in GoogleFonts', () {
    final font = GoogleFonts.notoSansGujarati();
    expect(font.fontFamily, isNotNull);
    final theme = GoogleFonts.notoSansGujaratiTextTheme();
    expect(theme.bodyMedium, isNotNull);
  });
}
