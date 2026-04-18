import 'dart:async' show Timer, TimeoutException;
import 'dart:convert';
import 'dart:io' show SocketException, File;
import 'dart:math' as math;
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/utils/app_constants.dart';
import '../../core/utils/battery_manager.dart';
import '../../core/utils/ultra_battery_saver.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/custom_button.dart';
import '../auth/login_screen.dart';
import '../dashboard/dashboard_screen.dart';

class SetupProfileScreen extends StatefulWidget {
  const SetupProfileScreen({super.key});

  @override
  State<SetupProfileScreen> createState() => _SetupProfileScreenState();
}

class _SetupProfileScreenState extends State<SetupProfileScreen>
    with TickerProviderStateMixin {
  final User? user = FirebaseAuth.instance.currentUser;

  final _usernameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _schoolController = TextEditingController();
  final _courseController = TextEditingController();
  final _hoursController = TextEditingController();

  final FocusNode _schoolFocusNode = FocusNode();
  final FocusNode _courseFocusNode = FocusNode();

  Timer? _debounceTimer;
  late AnimationController _bgAnimationController;
  late AnimationController _entryController;
  bool _isInitialized = false;

  bool _isLoading = false;
  bool _isProfileCompleted = false;
  Uint8List? _selectedPhotoBytes;
  Uint8List? _selectedResumeBytes;
  String? _uploadedPhotoUrl;
  String? _uploadedResumeUrl;
  String _selectedGender = 'Male';

  final Map<String, String> _schoolAliases = {
    "PTC": "Pateros Technological College",
    "RTU": "Rizal Technological College",
    "STI": "STI College",
    "PUP": "Polytechnic University Of The Philippines",
    "UST": "University Of Santo Tomas",
    "UP": "University Of The Philippines",
    "DLSU": "De La Salle University",
    "TUP": "Technological University Of The Philippines",
    "PLM": "Pamantasan Ng Lungsod Ng Maynila",
  };

  final Map<String, String> _courseAliases = {
    "BSIT": "Bachelor Of Science In Information Technology",
    "BSCS": "Bachelor Of Science In Computer Science",
    "BSCPE": "Bachelor Of Science In Computer Engineering",
    "BSEE": "Bachelor Of Science In Electrical Engineering",
    "BSECE": "Bachelor Of Science In Electronics Engineering",
    "BACOMM": "Bachelor Of Arts in Communication",
    "BSCE": "Bachelor Of Science In Civil Engineering",
    "BSPSYCH": "Bachelor Of Science In Psychology",
    "BSPSY": "Bachelor Of Science In Psychology",
  };

  late List<String> _dynamicSchoolSuggestions = _schoolAliases.values.toList();
  late List<String> _dynamicCourseSuggestions = _courseAliases.values.toList();

  @override
  void initState() {
    super.initState();

    _bgAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    );

    _entryController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: AppConstants.adaptiveAnimationDuration),
    );

    UltraBatterySaver.initialize();
    BatteryManager.initialize();
    AppConstants.updateFromUserPreferences();

    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    await Future.delayed(const Duration(milliseconds: 800));

    await _checkExistingProfile();
    await _fetchDynamicSuggestions();

    if (mounted) {
      if (AppConstants.shouldEnableAnyAnimations) {
        _bgAnimationController.repeat();
        _entryController.forward();
      } else {
        _entryController.value = 1.0;
      }

      setState(() {
        _isInitialized = true;
      });

      _usernameController.addListener(_onTextChanged);
      _phoneController.addListener(_onTextChanged);
      _addressController.addListener(_onTextChanged);
      _schoolController.addListener(_onTextChanged);
      _courseController.addListener(_onTextChanged);
      _hoursController.addListener(_onTextChanged);

      _loadDraft();
    }
  }

  void _onTextChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {});
        _saveDraft();
      }
    });
  }

  bool _isFormValid() {
    if (_usernameController.text.trim().isEmpty ||
        _phoneController.text.trim().isEmpty ||
        _addressController.text.trim().isEmpty ||
        _schoolController.text.trim().isEmpty ||
        _courseController.text.trim().isEmpty ||
        _hoursController.text.trim().isEmpty) {
      return false;
    }

    if (!_isValidPhone(_phoneController.text.trim())) {
      return false;
    }

    final parsedHours = double.tryParse(_hoursController.text.trim());
    if (parsedHours == null || parsedHours < 100) {
      return false;
    }

    if (_selectedResumeBytes == null && _uploadedResumeUrl == null) {
      return false;
    }

    return true;
  }

  bool _isValidPhone(String phone) {
    final cleanedPhone = phone.replaceAll(RegExp(r'[\s-]'), '');
    final regex = RegExp(r'^(\d{10}|\+63\d{10})$');
    return regex.hasMatch(cleanedPhone);
  }

  Future<void> _saveDraft() async {
    if (user == null || _isLoading) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final draftKey = 'profile_draft_${user!.uid}';

      final draftData = json.encode({
        'username': _usernameController.text,
        'phone': _phoneController.text,
        'address': _addressController.text,
        'school': _schoolController.text,
        'course': _courseController.text,
        'hours': _hoursController.text,
        'gender': _selectedGender,
        'savedAt': DateTime.now().toIso8601String(),
      });

      await prefs.setString(draftKey, draftData);
    } catch (e) {
      debugPrint("Auto-save error: $e");
    }
  }

  Future<void> _loadDraft() async {
    if (user == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final draftData = prefs.getString('profile_draft_${user!.uid}');

      if (draftData != null) {
        final draft = json.decode(draftData) as Map<String, dynamic>;
        final savedAt = DateTime.parse(draft['savedAt']);

        if (DateTime.now().difference(savedAt).inHours < 24) {
          setState(() {
            if (_usernameController.text.isEmpty) {
              _usernameController.text = draft['username'] ?? "";
            }
            if (_phoneController.text.isEmpty) {
              _phoneController.text = draft['phone'] ?? "";
            }
            if (_addressController.text.isEmpty) {
              _addressController.text = draft['address'] ?? "";
            }
            if (_schoolController.text.isEmpty) {
              _schoolController.text = draft['school'] ?? "";
            }
            if (_courseController.text.isEmpty) {
              _courseController.text = draft['course'] ?? "";
            }
            if (_hoursController.text.isEmpty) {
              _hoursController.text = draft['hours'] ?? "";
            }
            _selectedGender = draft['gender'] ?? 'Male';
          });
        }
      }
    } catch (e) {
      debugPrint("Load draft error: $e");
    }
  }

  Future<void> _fetchDynamicSuggestions() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('intern_profiles')
          .get();
      final Set<String> schools = {};
      final Set<String> courses = {};

      schools.addAll(_schoolAliases.values);
      courses.addAll(_courseAliases.values);

      for (var doc in snapshot.docs) {
        final data = doc.data();
        if (data['school'] != null &&
            data['school'].toString().trim().isNotEmpty) {
          schools.add(data['school'].toString().trim());
        }
        if (data['course'] != null &&
            data['course'].toString().trim().isNotEmpty) {
          courses.add(data['course'].toString().trim());
        }
      }

      if (mounted) {
        setState(() {
          _dynamicSchoolSuggestions = schools.toList();
          _dynamicCourseSuggestions = courses.toList();
        });
      }
    } catch (e) {
      debugPrint("Error fetching dynamic suggestions: $e");
    }
  }

  String _normalizeText(String input, Map<String, String> aliases) {
    String trimmed = input.trim();
    if (trimmed.isEmpty) return "";
    String upper = trimmed.toUpperCase();

    if (aliases.containsKey(upper)) return aliases[upper]!;

    List<String> words = trimmed.split(' ');
    if (words.isNotEmpty) {
      String firstWordUpper = words[0].toUpperCase();
      if (aliases.containsKey(firstWordUpper)) {
        words[0] = aliases[firstWordUpper]!;
        return words.map((w) => _formatToTitleCase(w)).join(' ');
      }
    }
    return _formatToTitleCase(trimmed);
  }

  String _formatToTitleCase(String text) {
    if (text.trim().isEmpty) return "";
    const acronyms = [
      'BS',
      'BA',
      'MS',
      'MA',
      'IT',
      'CS',
      'CPE',
      'CE',
      'BSA',
      'PHD',
    ];

    return text
        .trim()
        .split(' ')
        .where((w) => w.isNotEmpty)
        .map((w) {
          String upper = w.toUpperCase();
          if (acronyms.contains(upper)) return upper;
          if (w.length <= 1) return w.toUpperCase();
          return w[0].toUpperCase() + w.substring(1).toLowerCase();
        })
        .join(' ');
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _bgAnimationController.dispose();
    _entryController.dispose();
    _usernameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _schoolController.dispose();
    _courseController.dispose();
    _hoursController.dispose();
    _schoolFocusNode.dispose();
    _courseFocusNode.dispose();
    UltraBatterySaver.dispose();
    super.dispose();
  }

  Future<void> _checkExistingProfile() async {
    if (user == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('intern_profiles')
        .doc(user!.uid)
        .get();
    if (doc.exists) {
      final data = doc.data()!;
      setState(() {
        _isProfileCompleted = data['profile_setup_completed'] ?? false;
        _usernameController.text = data['username'] ?? "";
        _phoneController.text = data['phone'] ?? "";
        _addressController.text = data['address'] ?? "";
        _schoolController.text = data['school'] ?? "";
        _courseController.text = data['course'] ?? "";
        _hoursController.text = (data['required_hours'] ?? 0).toString();
        _selectedGender = data['gender'] ?? 'Male';
        _uploadedPhotoUrl = data['photo_url'];
        _uploadedResumeUrl = data['resume_url'];
      });
    }
  }

  Future<void> _pickImage() async {
    HapticFeedback.lightImpact();
    final result = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (result != null) {
      final bytes = await result.readAsBytes();
      setState(() {
        _selectedPhotoBytes = bytes;
      });
      _onTextChanged();
    }
  }

  Future<void> _pickResume() async {
    HapticFeedback.lightImpact();
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );

    if (result != null) {
      final platformFile = result.files.first;
      Uint8List? bytes = platformFile.bytes;

      if (bytes == null && platformFile.path != null) {
        bytes = await File(platformFile.path!).readAsBytes();
      }

      if (bytes != null) {
        setState(() {
          _selectedResumeBytes = bytes;
        });
        _onTextChanged();
      }
    }
  }

  // --- DELETE LOGIC ---
  Future<void> _deletePhoto() async {
    HapticFeedback.mediumImpact();
    if (_selectedPhotoBytes != null) {
      setState(() => _selectedPhotoBytes = null);
      return;
    }
    if (_uploadedPhotoUrl != null) {
      final confirm = await _showDeleteConfirmDialog("Delete profile picture?");
      if (confirm == true) {
        setState(() => _isLoading = true);
        await FirebaseFirestore.instance
            .collection('intern_profiles')
            .doc(user!.uid)
            .update({'photo_url': FieldValue.delete()});
        setState(() {
          _uploadedPhotoUrl = null;
          _isLoading = false;
        });
        if (mounted) AppSnackbar.success(context, 'Photo removed.');
      }
    }
  }

  Future<void> _deleteResume() async {
    HapticFeedback.mediumImpact();
    if (_selectedResumeBytes != null) {
      setState(() => _selectedResumeBytes = null);
      return;
    }
    if (_uploadedResumeUrl != null) {
      final confirm = await _showDeleteConfirmDialog("Delete uploaded resume?");
      if (confirm == true) {
        setState(() => _isLoading = true);
        await FirebaseFirestore.instance
            .collection('intern_profiles')
            .doc(user!.uid)
            .update({'resume_url': FieldValue.delete()});
        setState(() {
          _uploadedResumeUrl = null;
          _isLoading = false;
        });
        if (mounted) AppSnackbar.success(context, 'Resume removed.');
      }
    }
  }

  Future<bool?> _showDeleteConfirmDialog(String title) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return showDialog<bool>(
      context: context,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1A1C20) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          content: const Text("This action cannot be undone."),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("CANCEL", style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                "DELETE",
                style: TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showLogoutConfirmation(BuildContext context) async {
    HapticFeedback.mediumImpact();
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (BuildContext dialogContext) {
        final bool isDark = Theme.of(context).brightness == Brightness.dark;
        final dialogBg = isDark ? const Color(0xFF1A1C20) : Colors.white;
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Dialog(
            backgroundColor: dialogBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            elevation: 24,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Container(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Colors.redAccent, Colors.red],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.redAccent.withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.logout_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      "Logout",
                      style: TextStyle(
                        color: isDark ? Colors.white : AppTheme.primaryDark,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "Are you sure you want to end your current session?",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 32),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              side: BorderSide(
                                color: isDark
                                    ? Colors.grey.shade800
                                    : Colors.grey.shade300,
                                width: 1.5,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: Text(
                              "Cancel",
                              style: TextStyle(
                                color: isDark ? Colors.white : AppTheme.primaryDark,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              gradient: const LinearGradient(
                                colors: [Colors.redAccent, Colors.red],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.redAccent.withOpacity(0.4),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: () async {
                                HapticFeedback.mediumImpact();
                                Navigator.of(dialogContext).pop();
                                await FirebaseAuth.instance.signOut();
                                if (mounted) {
                                  Navigator.pushAndRemoveUntil(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const LoginScreen(),
                                    ),
                                    (route) => false,
                                  );
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                elevation: 0,
                              ),
                              child: const Text(
                                "Logout",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _handlePdfPreview() async {
    if (_selectedResumeBytes != null) {
      const fileSizeLimit = 5 * 1024 * 1024;
      final isLargeFile = _selectedResumeBytes!.length > fileSizeLimit;

      if (isLargeFile) {
        AppSnackbar.warning(context, 'File too large.');
        return;
      }

      try {
        final bool isDark = Theme.of(context).brightness == Brightness.dark;
        showDialog(
          context: context,
          barrierDismissible: true,
          builder: (context) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: EdgeInsets.zero,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.9,
              height: MediaQuery.of(context).size.height * 0.8,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A1C20) : Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  AppBar(
                    backgroundColor: isDark
                        ? AppTheme.gradient2Dark
                        : AppTheme.gradient2Light,
                    title: Text(
                      "PDF PREVIEW",
                      style: TextStyle(
                        color: isDark ? Colors.white : AppTheme.primaryDark,
                      ),
                    ),
                    actions: [
                      IconButton(
                        icon: Icon(
                          Icons.close,
                          color: isDark ? Colors.white : AppTheme.primaryDark,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      child: SfPdfViewer.memory(
                        _selectedResumeBytes!,
                        canShowScrollHead: true,
                        canShowScrollStatus: true,
                        onDocumentLoadFailed: (details) {
                          Navigator.pop(context);
                          AppSnackbar.error(context, 'PDF load failed.');
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      } catch (e) {
        AppSnackbar.error(context, 'Preview failed.');
      }
    } else if (_uploadedResumeUrl != null) {
      try {
        final Uri url = Uri.parse(_uploadedResumeUrl!);
        if (await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.externalApplication);
        } else {
          AppSnackbar.error(context, 'Cannot open URL.');
        }
      } catch (e) {
        AppSnackbar.error(context, 'Open failed.');
      }
    }
  }

  Future<String?> _uploadToCloudinaryWithRetry({
    required Uint8List fileBytes,
    required String fileName,
    required String publicId,
    int maxRetries = 3,
  }) async {
    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        final url = await _uploadToCloudinary(
          fileBytes: fileBytes,
          fileName: fileName,
          publicId: publicId,
        );
        return url;
      } catch (e) {
        if (attempt == maxRetries - 1) rethrow;
        await Future.delayed(Duration(milliseconds: 1000 * (attempt + 1)));
      }
    }
    return null;
  }

  Future<String> _uploadToCloudinary({
    required Uint8List fileBytes,
    required String fileName,
    required String publicId,
  }) async {
    final url = Uri.parse(
      'https://api.cloudinary.com/v1_1/dqn0uoaqm/auto/upload',
    );
    final request = http.MultipartRequest('POST', url);
    request.fields['upload_preset'] = 'zhiyuan_preset';
    request.fields['public_id'] = publicId;
    request.fields['resource_type'] = 'auto';

    request.files.add(
      http.MultipartFile.fromBytes('file', fileBytes, filename: fileName),
    );

    final response = await request.send();
    final respStr = await response.stream.bytesToString();
    final jsonResponse = json.decode(respStr);

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonResponse['secure_url'];
    } else {
      final errorMessage =
          jsonResponse['error']?['message'] ?? 'Unknown Cloudinary Error';
      throw Exception(errorMessage);
    }
  }

  Future<void> _saveProfile() async {
    if (!_isFormValid()) return;

    HapticFeedback.mediumImpact();
    setState(() => _isLoading = true);

    try {
      final parsedHours = double.parse(_hoursController.text.trim());

      if (_selectedPhotoBytes != null) {
        final photoUrl = await _uploadToCloudinaryWithRetry(
          fileBytes: _selectedPhotoBytes!,
          fileName: 'profile_pic',
          publicId: "profile_${user!.uid}",
        );
        if (photoUrl != null) {
          _uploadedPhotoUrl = photoUrl;
        }
      }

      if (_selectedResumeBytes != null) {
        final resumeUrl = await _uploadToCloudinaryWithRetry(
          fileBytes: _selectedResumeBytes!,
          fileName: 'resume.pdf',
          publicId: "resume_${user!.uid}",
        );
        if (resumeUrl != null) {
          _uploadedResumeUrl = resumeUrl;
        }
      }

      await FirebaseFirestore.instance
          .collection('intern_profiles')
          .doc(user?.uid)
          .set({
            'username': _formatToTitleCase(_usernameController.text),
            'phone': _phoneController.text.trim(),
            'address': _addressController.text.trim(),
            'gender': _selectedGender,
            'school': _normalizeText(_schoolController.text, _schoolAliases),
            'course': _normalizeText(_courseController.text, _courseAliases),
            'required_hours': parsedHours,
            'photo_url': _uploadedPhotoUrl,
            'resume_url': _uploadedResumeUrl,
            'profile_setup_completed': true,
            'updated_at': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      await FirebaseFirestore.instance.collection('users').doc(user?.uid).set({
        'profile_setup_completed': true,
      }, SetOptions(merge: true));

      if (user != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('profile_draft_${user!.uid}');
      }

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const DashboardScreen()),
        );
      }
    } on SocketException {
      AppSnackbar.error(context, 'No internet.');
    } on TimeoutException {
      AppSnackbar.error(context, 'Connection timeout.');
    } catch (e) {
      debugPrint("UPLOAD ERROR: $e");
      AppSnackbar.error(context, 'Upload failed.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  double _calculateProgress() {
    int filledFields = 0;
    int totalFields = 7;

    if (_usernameController.text.trim().isNotEmpty) filledFields++;
    if (_phoneController.text.trim().isNotEmpty) filledFields++;
    if (_addressController.text.trim().isNotEmpty) filledFields++;
    if (_schoolController.text.trim().isNotEmpty) filledFields++;
    if (_courseController.text.trim().isNotEmpty) filledFields++;

    final parsedHours = double.tryParse(_hoursController.text.trim());
    if (parsedHours != null && parsedHours >= 100) filledFields++;
    if (_selectedResumeBytes != null || _uploadedResumeUrl != null)
      filledFields++;

    return filledFields / totalFields;
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color cardBg = isDark
        ? const Color(0x1AFFFFFF)
        : const Color(0xE6FFFFFF);
    final double progressValue = _calculateProgress();
    final bool isNestedInDashboard =
        context.findAncestorWidgetOfExactType<DashboardScreen>() != null;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          if (!isNestedInDashboard) ...[
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _bgAnimationController,
                builder: (context, child) {
                  return CustomPaint(
                    painter: MeshGradientPainter(
                      animationValue: _bgAnimationController.value,
                      isDark: isDark,
                    ),
                  );
                },
              ),
            ),
            Positioned.fill(
              child: Opacity(
                opacity: 0.02,
                child: Center(
                  child: Image.asset(
                    'assets/images/zhiyuan_logo.png',
                    width: MediaQuery.of(context).size.width * 0.6,
                    height: MediaQuery.of(context).size.height * 0.6,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ],

          AnimatedSwitcher(
            duration: const Duration(milliseconds: 800),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: !_isInitialized
                ? _buildPremiumLoading(isDark, cardBg)
                : _buildMainForm(isDark, cardBg, progressValue),
          ),

          if (_isInitialized && !_isProfileCompleted)
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              right: 16,
              child: IconButton(
                icon: Icon(
                  Icons.logout_rounded,
                  color: isDark
                      ? Colors.white70
                      : AppTheme.primaryDark.withValues(alpha: 0.7),
                  size: 28,
                  shadows: [
                    Shadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                onPressed: () => _showLogoutConfirmation(context),
                tooltip: 'Logout',
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPremiumLoading(bool isDark, Color cardBg) {
    return Center(
      key: const ValueKey('loading_screen'),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 40),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: Colors.white.withValues(alpha: isDark ? 0.08 : 0.6),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                  blurRadius: 50,
                  spreadRadius: 10,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  height: 50,
                  width: 50,
                  child: CircularProgressIndicator(
                    color: AppTheme.primaryGold,
                    strokeWidth: 3,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  "Syncing Profile...",
                  style: TextStyle(
                    color: isDark ? Colors.grey.shade300 : AppTheme.primaryDark,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMainForm(bool isDark, Color cardBg, double progressValue) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: FadeTransition(
            opacity: _entryController,
            child: SlideTransition(
              position:
                  Tween<Offset>(
                    begin: const Offset(0, 0.1),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(
                      parent: _entryController,
                      curve: Curves.easeOutCubic,
                    ),
                  ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                  child: Container(
                    padding: const EdgeInsets.all(40),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(
                        color: Colors.white.withValues(
                          alpha: isDark ? 0.08 : 0.6,
                        ),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: isDark ? 0.2 : 0.05,
                          ),
                          blurRadius: 50,
                          spreadRadius: 10,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildProgressHeader(isDark, progressValue),
                        _buildProfilePic(),
                        const SizedBox(height: 30),
                        _buildCardContainer(cardBg, [
                          _buildTextField(
                            _usernameController,
                            "Full Name *",
                            Icons.person,
                            isDark,
                            autoCapitalize: true,
                          ),
                          const SizedBox(height: 15),
                          Row(
                            children: [
                              Expanded(child: _buildGenderDropdown(isDark)),
                              const SizedBox(width: 15),
                              Expanded(
                                child: _buildTextField(
                                  _hoursController,
                                  "Req. Hours",
                                  Icons.timer,
                                  isDark,
                                  isNumber: true,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 15),
                          _buildPhoneField(isDark),
                          const SizedBox(height: 15),
                          _buildTextField(
                            _addressController,
                            "Address",
                            Icons.home,
                            isDark,
                          ),
                        ]),
                        const SizedBox(height: 20),
                        _buildCardContainer(cardBg, [
                          _buildAutocompleteField(
                            controller: _schoolController,
                            focusNode: _schoolFocusNode,
                            label: "School",
                            icon: Icons.school,
                            isDark: isDark,
                            autoCapitalize: true,
                            suggestions: _dynamicSchoolSuggestions,
                          ),
                          const SizedBox(height: 15),
                          _buildAutocompleteField(
                            controller: _courseController,
                            focusNode: _courseFocusNode,
                            label: "Course",
                            icon: Icons.book,
                            isDark: isDark,
                            autoCapitalize: true,
                            suggestions: _dynamicCourseSuggestions,
                          ),
                        ]),
                        const SizedBox(height: 30),
                        _buildResumeBox(isDark, cardBg),
                        const SizedBox(height: 40),
                        _buildSaveButton(isDark),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressHeader(bool isDark, double progressValue) {
    return Column(
      children: [
        Text(
          'SETUP PROFILE',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
            color: isDark ? Colors.white : AppTheme.primaryDark,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${(progressValue * 100).toInt()}% COMPLETE',
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppTheme.primaryGold,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: progressValue,
            backgroundColor: isDark ? Colors.white10 : Colors.black12,
            color: AppTheme.primaryGold,
            minHeight: 6,
          ),
        ),
        const SizedBox(height: 30),
      ],
    );
  }

  Widget _buildProfilePic() {
    final bool hasImage =
        _selectedPhotoBytes != null || _uploadedPhotoUrl != null;
    return Stack(
      alignment: Alignment.center,
      children: [
        GestureDetector(
          onTap: _pickImage,
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.primaryGold, width: 3),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryGold.withValues(alpha: 0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: CircleAvatar(
              radius: 58,
              backgroundColor: AppTheme.primaryGold.withValues(alpha: 0.1),
              backgroundImage: _selectedPhotoBytes != null
                  ? MemoryImage(_selectedPhotoBytes!)
                  : (_uploadedPhotoUrl != null
                        ? NetworkImage(_uploadedPhotoUrl!)
                        : null),
              child: !hasImage
                  ? const Icon(
                      Icons.camera_alt,
                      color: AppTheme.primaryGold,
                      size: 30,
                    )
                  : null,
            ),
          ),
        ),
        if (hasImage)
          Positioned(
            top: 0,
            right: 0,
            child: GestureDetector(
              onTap: _deletePhoto,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Colors.redAccent,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8)],
                ),
                child: const Icon(
                  Icons.delete_forever_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCardContainer(Color cardBg, List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildPhoneField(bool isDark) {
    return TextField(
      controller: _phoneController,
      keyboardType: TextInputType.phone,
      style: TextStyle(color: isDark ? Colors.white : Colors.black),
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(10),
      ],
      decoration: InputDecoration(
        labelText: 'Mobile Number',
        labelStyle: TextStyle(
          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
          fontSize: 13,
        ),
        prefixText: '+63 ',
        prefixIcon: const Icon(
          Icons.phone,
          color: AppTheme.primaryGold,
          size: 20,
        ),
        filled: true,
        fillColor: isDark ? const Color(0x1A000000) : const Color(0x80FFFFFF),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.transparent),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppTheme.primaryGold, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon,
    bool isDark, {
    bool isNumber = false,
    bool autoCapitalize = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      textCapitalization: autoCapitalize
          ? TextCapitalization.words
          : TextCapitalization.none,
      style: TextStyle(color: isDark ? Colors.white : Colors.black),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
          fontSize: 13,
        ),
        prefixIcon: Icon(icon, color: AppTheme.primaryGold, size: 20),
        filled: true,
        fillColor: isDark ? const Color(0x1A000000) : const Color(0x80FFFFFF),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.transparent),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppTheme.primaryGold, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildAutocompleteField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    required IconData icon,
    required bool isDark,
    required Iterable<String> suggestions,
    bool autoCapitalize = false,
  }) {
    return RawAutocomplete<String>(
      textEditingController: controller,
      focusNode: focusNode,
      optionsBuilder: (textValue) => textValue.text.isEmpty
          ? const Iterable<String>.empty()
          : suggestions.where(
              (opt) => opt.toLowerCase().contains(textValue.text.toLowerCase()),
            ),
      onSelected: (selection) {
        controller.text = selection;
        _onTextChanged();
      },
      fieldViewBuilder:
          (context, fieldController, fieldFocus, onFieldSubmitted) => TextField(
            controller: fieldController,
            focusNode: fieldFocus,
            textCapitalization: autoCapitalize
                ? TextCapitalization.words
                : TextCapitalization.none,
            style: TextStyle(color: isDark ? Colors.white : Colors.black),
            decoration: InputDecoration(
              labelText: label,
              labelStyle: TextStyle(
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                fontSize: 13,
              ),
              prefixIcon: Icon(icon, color: AppTheme.primaryGold, size: 20),
              filled: true,
              fillColor: isDark
                  ? const Color(0x1A000000)
                  : const Color(0x80FFFFFF),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Colors.transparent),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: AppTheme.primaryGold,
                  width: 1.5,
                ),
              ),
            ),
          ),
      optionsViewBuilder: (context, onSelected, options) => Align(
        alignment: Alignment.topLeft,
        child: Material(
          elevation: 4.0,
          borderRadius: BorderRadius.circular(14),
          color: isDark ? const Color(0xFF1A1C20) : Colors.white,
          child: ListView.builder(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            itemCount: options.length,
            itemBuilder: (context, index) => InkWell(
              onTap: () => onSelected(options.elementAt(index)),
              child: Padding(
                padding: const EdgeInsets.all(15.0),
                child: Text(
                  options.elementAt(index),
                  style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGenderDropdown(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(14),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedGender,
          isExpanded: true,
          style: TextStyle(color: isDark ? Colors.white : Colors.black),
          items: ['Male', 'Female', 'Other']
              .map((val) => DropdownMenuItem(value: val, child: Text(val)))
              .toList(),
          onChanged: (val) {
            HapticFeedback.selectionClick();
            setState(() => _selectedGender = val!);
            _onTextChanged();
          },
        ),
      ),
    );
  }

  Widget _buildResumeBox(bool isDark, Color cardBg) {
    final bool hasResume =
        _selectedResumeBytes != null || _uploadedResumeUrl != null;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.description, color: AppTheme.primaryGold, size: 20),
              SizedBox(width: 10),
              Text(
                'Resume *',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 15),
          if (hasResume)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryGold.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.primaryGold.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle,
                    color: AppTheme.primaryGold,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _selectedResumeBytes != null
                          ? 'Local PDF Selected'
                          : 'Resume Uploaded',
                      style: const TextStyle(
                        color: AppTheme.primaryGold,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.visibility,
                      color: AppTheme.primaryGold,
                    ),
                    onPressed: _handlePdfPreview,
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: Colors.redAccent,
                    ),
                    onPressed: _deleteResume,
                  ),
                ],
              ),
            )
          else
            InkWell(
              onTap: _pickResume,
              child: Container(
                width: double.infinity,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(
                      Icons.upload_file,
                      color: AppTheme.primaryGold,
                      size: 24,
                    ),
                    SizedBox(height: 5),
                    Text(
                      'Upload Resume (Mandatory)',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSaveButton(bool isDark) {
    final bool isButtonDisabled = !_isFormValid() || _isLoading;
    return CustomButton(
      text: 'SAVE PROFILE',
      onPressed: isButtonDisabled ? null : _saveProfile,
      variant: ButtonVariant.primary,
      size: ButtonSize.medium,
      isLoading: _isLoading,
      isFullWidth: true,
    );
  }
}

class MeshGradientPainter extends CustomPainter {
  final double animationValue;
  final bool isDark;
  MeshGradientPainter({required this.animationValue, required this.isDark});
  @override
  void paint(Canvas canvas, Size size) {
    final Color color1 = isDark
        ? const Color(0xFFCC5500).withValues(alpha: 0.6)
        : const Color(0xFFFFDAB9).withValues(alpha: 0.8);
    final Color color2 = isDark
        ? const Color(0xFFC2A984).withValues(alpha: 0.5)
        : const Color(0xFFEADDCA).withValues(alpha: 0.7);
    final double w = size.width, h = size.height;
    final double x1 =
        w * 0.5 + math.sin(animationValue * math.pi * 2) * w * 0.3;
    final double y1 =
        h * 0.2 + math.cos(animationValue * math.pi * 2) * h * 0.2;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()
        ..color = isDark ? const Color(0xFF141619) : const Color(0xFFF8F9FA),
    );
    final Paint paint1 = Paint()
      ..shader = RadialGradient(
        colors: [color1, color1.withValues(alpha: 0.0)],
        stops: const [0.2, 1.0],
      ).createShader(Rect.fromCircle(center: Offset(x1, y1), radius: w * 0.8))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 50);
    canvas.drawCircle(Offset(x1, y1), w * 0.8, paint1);
    final Paint arcPaint = Paint()
      ..color = isDark
          ? Colors.white.withValues(alpha: 0.03)
          : Colors.black.withValues(alpha: 0.02)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(w * 0.5, h * 0.5),
        width: w * 1.5,
        height: w * 1.5,
      ),
      0,
      math.pi * 1.5,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(covariant MeshGradientPainter oldDelegate) => true;
}
