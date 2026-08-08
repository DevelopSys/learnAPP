import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:learnapp/main.dart';

import '../model/course.dart';

const Color accentColor = Color(0xFF3ECF8E);

class ApiConfig {
  static const String baseUrl = 'https://learnback-c8vp.onrender.com';
  static const String apiPrefix = '/api';

  static String get fullBaseUrl => '$baseUrl$apiPrefix';
}

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final TextEditingController usernameController =
  TextEditingController();

  final TextEditingController emailController =
  TextEditingController();

  final TextEditingController passwordController =
  TextEditingController();

  final TextEditingController confirmPasswordController =
  TextEditingController();

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    clientId:
    '274784370368-l4cuagutrl9ilnjc0ur80lut3mpeb55j.apps.googleusercontent.com',
  );

  bool isLoading = false;
  bool isGoogleLoading = false;
  bool isLoadingCourses = false;

  bool showPassword = false;
  bool showConfirmPassword = false;

  String? errorMessage;
  String? successMessage;

  String? googleId;
  String? googleEmail;
  String? googleDisplayName;

  String selectedRole = 'ADMINISTRACION';

  List<Course> availableCourses = [];
  List<int> selectedCourseIds = [];

  bool get isDark =>
      Theme.of(context).brightness == Brightness.dark;

  Color get primaryColor =>
      isDark
          ? const Color(0xFF8B9CFF)
          : const Color(0xFF536DFE);

  Color get backgroundColor =>
      isDark
          ? const Color(0xFF0C111D)
          : const Color(0xFFF5F7FB);

  Color get cardColor =>
      isDark
          ? const Color(0xFF151C2B)
          : Colors.white;

  Color get textColor =>
      isDark
          ? Colors.white
          : const Color(0xFF172033);

  Color borderColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF2A2F3A)
          : const Color(0xFFD7DEE8);

  Color mutedTextColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? Colors.white.withOpacity(0.7)
          : Colors.black.withOpacity(0.65);

  @override
  void initState() {
    super.initState();
    loadCourses();
  }

  @override
  void dispose() {
    usernameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> loadCourses() async {
    setState(() {
      isLoadingCourses = true;
      errorMessage = null;
    });

    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.fullBaseUrl}/public/courses'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      print('STATUS COURSES: ${response.statusCode}');
      print('BODY COURSES: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        if (decoded is List) {
          final courses = decoded
              .map(
                (e) => Course.fromJson(
              e as Map<String, dynamic>,
            ),
          )
              .toList();

          setState(() {
            availableCourses = courses;
          });
        } else {
          setState(() {
            errorMessage =
            'La respuesta de cursos no tiene formato de lista';
          });
        }
      } else {
        setState(() {
          errorMessage =
          'Error al cargar ciclos (${response.statusCode}): ${response.body}';
        });
      }
    } catch (e) {
      print('ERROR LOAD COURSES: $e');

      setState(() {
        errorMessage = 'Error al cargar ciclos: $e';
      });
    } finally {
      if (!mounted) return;

      setState(() {
        isLoadingCourses = false;
      });
    }
  }

  Future<void> seleccionarCuentaGoogle() async {
    setState(() {
      isGoogleLoading = true;
      errorMessage = null;
      successMessage = null;
    });

    try {
      await _googleSignIn.signOut();

      final GoogleSignInAccount? account =
      await _googleSignIn.signIn();

      if (account == null) {
        setState(() {
          errorMessage =
          'Se canceló la selección de cuenta Google';
        });
        return;
      }

      setState(() {
        googleId = account.id;
        googleEmail = account.email;
        googleDisplayName = account.displayName;

        if (emailController.text.trim().isEmpty) {
          emailController.text = account.email;
        }

        if (usernameController.text.trim().isEmpty &&
            account.displayName != null &&
            account.displayName!.trim().isNotEmpty) {
          usernameController.text =
              account.displayName!.trim();
        }

        successMessage =
        'Cuenta Google seleccionada correctamente';
      });
    } catch (e) {
      setState(() {
        errorMessage = 'No se pudo conectar con Google';
      });
    } finally {
      if (!mounted) return;

      setState(() {
        isGoogleLoading = false;
      });
    }
  }

  void quitarCuentaGoogle() {
    setState(() {
      googleId = null;
      googleEmail = null;
      googleDisplayName = null;
      successMessage =
      'Cuenta Google desvinculada del formulario';
    });
  }

  void toggleCourseSelection(
      int courseId,
      bool selected,
      ) {
    setState(() {
      if (selected) {
        if (!selectedCourseIds.contains(courseId)) {
          selectedCourseIds.add(courseId);
        }
      } else {
        selectedCourseIds.remove(courseId);
      }
    });
  }

  Future<void> register() async {
    final username = usernameController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text.trim();
    final confirmPassword =
    confirmPasswordController.text.trim();

    if (username.isEmpty ||
        email.isEmpty ||
        password.isEmpty ||
        confirmPassword.isEmpty) {
      setState(() {
        errorMessage = 'Completa todos los campos';
        successMessage = null;
      });
      return;
    }

    if (password != confirmPassword) {
      setState(() {
        errorMessage = 'Las contraseñas no coinciden';
        successMessage = null;
      });
      return;
    }

    if (password.length < 4) {
      setState(() {
        errorMessage =
        'La contraseña debe tener al menos 4 caracteres';
        successMessage = null;
      });
      return;
    }

    if (selectedRole == 'COORDINADOR' &&
        selectedCourseIds.isEmpty) {
      setState(() {
        errorMessage =
        'Selecciona al menos un ciclo si la cuenta es de coordinador';
        successMessage = null;
      });
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
      successMessage = null;
    });

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.fullBaseUrl}/auth/register'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'username': username,
          'email': email,
          'password': password,
          'role': selectedRole,
          'courseIds': selectedRole == 'COORDINADOR'
              ? selectedCourseIds
              : [],
          'googleId': googleId,
          'googleEmail': googleEmail,
          'googleLinked':
          googleEmail != null && googleEmail!.isNotEmpty,
          'authProvider':
          googleEmail != null && googleEmail!.isNotEmpty
              ? 'LOCAL_GOOGLE'
              : 'LOCAL',
        }),
      );

      if (response.statusCode == 200 ||
          response.statusCode == 201) {
        setState(() {
          successMessage = googleEmail != null
              ? 'Usuario registrado y cuenta Google asociada correctamente'
              : 'Usuario registrado correctamente';

          errorMessage = null;
        });

        await Future.delayed(
          const Duration(milliseconds: 1200),
        );

        if (!mounted) return;

        Navigator.pop(context);
      } else {
        setState(() {
          errorMessage = response.body.isNotEmpty
              ? response.body
              : 'Error al registrar usuario (${response.statusCode})';

          successMessage = null;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage =
        'No se pudo conectar con el servidor';
        successMessage = null;
      });
    } finally {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });
    }
  }

  Widget buildCourseSelector(BuildContext context) {
    if (selectedRole != 'COORDINADOR') {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 22),
        _sectionTitle(
          'Ciclos asignados',
          Icons.school_outlined,
        ),
        const SizedBox(height: 6),
        Text(
          'Selecciona los ciclos de los que será coordinador',
          style: TextStyle(
            color: mutedTextColor(context),
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 14),
        if (isLoadingCourses)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: _boxDecoration(context),
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  'Cargando ciclos...',
                  style: TextStyle(
                    color: mutedTextColor(context),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 10),
                LinearProgressIndicator(
                  minHeight: 5,
                  borderRadius: BorderRadius.circular(10),
                  color: primaryColor,
                  backgroundColor:
                  primaryColor.withOpacity(.12),
                ),
              ],
            ),
          )
        else if (availableCourses.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: _boxDecoration(context),
            child: Text(
              'No hay ciclos disponibles',
              style: TextStyle(
                color: mutedTextColor(context),
              ),
            ),
          )
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: _boxDecoration(context),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: availableCourses.map((course) {
                final selected =
                selectedCourseIds.contains(course.id);

                final label = course.acronym.trim().isNotEmpty
                    ? '${course.acronym} · ${course.name}'
                    : course.name;

                return FilterChip(
                  label: Text(label),
                  selected: selected,
                  selectedColor:
                  primaryColor.withOpacity(.18),
                  checkmarkColor: primaryColor,
                  backgroundColor: isDark
                      ? const Color(0xFF101725)
                      : const Color(0xFFF8FAFC),
                  side: BorderSide(
                    color: selected
                        ? primaryColor
                        : borderColor(context),
                  ),
                  labelStyle: TextStyle(
                    color: selected
                        ? primaryColor
                        : textColor,
                    fontWeight: selected
                        ? FontWeight.w600
                        : FontWeight.w400,
                  ),
                  onSelected: (value) {
                    toggleCourseSelection(
                      course.id,
                      value,
                    );
                  },
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  InputDecoration _inputDecoration(
      BuildContext context, {
        required String hintText,
        required IconData icon,
        Widget? suffixIcon,
      }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(
        color: mutedTextColor(context),
      ),
      prefixIcon: Icon(
        icon,
        color: mutedTextColor(context),
        size: 21,
      ),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: isDark
          ? const Color(0xFF101725)
          : const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 17,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: borderColor(context),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: primaryColor,
          width: 1.5,
        ),
      ),
    );
  }

  BoxDecoration _boxDecoration(
      BuildContext context,
      ) {
    return BoxDecoration(
      color: isDark
          ? const Color(0xFF101725)
          : const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
        color: borderColor(context),
      ),
    );
  }

  Widget _sectionTitle(
      String text,
      IconData icon,
      ) {
    return Row(
      children: [
        Icon(
          icon,
          size: 19,
          color: primaryColor,
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            color: textColor,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _messageBox({
    required String message,
    required bool isSuccess,
  }) {
    final color = isSuccess
        ? Colors.green
        : Colors.redAccent;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: color.withOpacity(.10),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: color.withOpacity(.28),
        ),
      ),
      child: Row(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Icon(
            isSuccess
                ? Icons.check_circle_outline_rounded
                : Icons.error_outline_rounded,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: color,
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _googleAccountCard(BuildContext context) {
    if (googleEmail == null) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: primaryColor.withOpacity(.08),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: primaryColor.withOpacity(.35),
        ),
      ),
      child: Row(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 21,
            backgroundColor:
            primaryColor.withOpacity(.15),
            child: Icon(
              Icons.account_circle_outlined,
              color: primaryColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  'Cuenta Google seleccionada',
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                if (googleDisplayName != null &&
                    googleDisplayName!.isNotEmpty)
                  Text(
                    googleDisplayName!,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 13,
                    ),
                  ),
                Text(
                  googleEmail!,
                  style: TextStyle(
                    color: mutedTextColor(context),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: quitarCuentaGoogle,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 30),
                    tapTargetSize:
                    MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Quitar cuenta'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: Stack(
        children: [
          Positioned(
            top: -110,
            right: -90,
            child: _decorativeCircle(
              260,
              primaryColor.withOpacity(.12),
            ),
          ),
          Positioned(
            bottom: -140,
            left: -120,
            child: _decorativeCircle(
              300,
              accentColor.withOpacity(.07),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(
                  top: 8,
                  right: 16,
                ),
                child: IconButton(
                  tooltip: isDark
                      ? 'Cambiar a tema claro'
                      : 'Cambiar a tema oscuro',
                  onPressed: () {
                    MyApp.of(context).toggleTheme();
                  },
                  icon: Icon(
                    isDark
                        ? Icons.light_mode_outlined
                        : Icons.dark_mode_outlined,
                    color: textColor,
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  24,
                  54,
                  24,
                  32,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 560,
                  ),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(
                      28,
                      30,
                      28,
                      24,
                    ),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: borderColor(context),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(
                            isDark ? .22 : .07,
                          ),
                          blurRadius: 35,
                          offset: const Offset(0, 18),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 66,
                            height: 66,
                            decoration: BoxDecoration(
                              color: primaryColor.withOpacity(.13),
                              borderRadius:
                              BorderRadius.circular(21),
                            ),
                            child: Icon(
                              Icons.person_add_alt_1_rounded,
                              size: 32,
                              color: primaryColor,
                            ),
                          ),
                        ),
                        const SizedBox(height: 21),
                        Center(
                          child: Text(
                            'Crear una cuenta',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: textColor,
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Center(
                          child: Text(
                            'Completa tus datos para empezar a utilizar la plataforma',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: mutedTextColor(context),
                              fontSize: 14,
                              height: 1.4,
                            ),
                          ),
                        ),
                        const SizedBox(height: 30),
                        _sectionTitle(
                          'Datos personales',
                          Icons.person_outline_rounded,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Nombre de usuario',
                          style: TextStyle(
                            color: textColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: usernameController,
                          decoration: _inputDecoration(
                            context,
                            hintText: 'Introduce tu usuario',
                            icon: Icons.person_outline_rounded,
                          ),
                        ),
                        const SizedBox(height: 17),
                        Text(
                          'Correo electrónico',
                          style: TextStyle(
                            color: textColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: emailController,
                          keyboardType:
                          TextInputType.emailAddress,
                          decoration: _inputDecoration(
                            context,
                            hintText: 'tu@email.com',
                            icon: Icons.mail_outline_rounded,
                          ),
                        ),
                        const SizedBox(height: 17),
                        Text(
                          'Contraseña',
                          style: TextStyle(
                            color: textColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: passwordController,
                          obscureText: !showPassword,
                          decoration: _inputDecoration(
                            context,
                            hintText: 'Introduce tu contraseña',
                            icon: Icons.lock_outline_rounded,
                            suffixIcon: IconButton(
                              tooltip: showPassword
                                  ? 'Ocultar contraseña'
                                  : 'Mostrar contraseña',
                              onPressed: () {
                                setState(() {
                                  showPassword =
                                  !showPassword;
                                });
                              },
                              icon: Icon(
                                showPassword
                                    ? Icons
                                    .visibility_off_outlined
                                    : Icons
                                    .visibility_outlined,
                                color:
                                mutedTextColor(context),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 17),
                        Text(
                          'Confirmar contraseña',
                          style: TextStyle(
                            color: textColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller:
                          confirmPasswordController,
                          obscureText: !showConfirmPassword,
                          decoration: _inputDecoration(
                            context,
                            hintText:
                            'Repite tu contraseña',
                            icon: Icons.lock_reset_outlined,
                            suffixIcon: IconButton(
                              tooltip: showConfirmPassword
                                  ? 'Ocultar contraseña'
                                  : 'Mostrar contraseña',
                              onPressed: () {
                                setState(() {
                                  showConfirmPassword =
                                  !showConfirmPassword;
                                });
                              },
                              icon: Icon(
                                showConfirmPassword
                                    ? Icons
                                    .visibility_off_outlined
                                    : Icons
                                    .visibility_outlined,
                                color:
                                mutedTextColor(context),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 25),
                        _sectionTitle(
                          'Tipo de cuenta',
                          Icons.admin_panel_settings_outlined,
                        ),
                        const SizedBox(height: 14),
                        DropdownButtonFormField<String>(
                          value: selectedRole,
                          decoration: _inputDecoration(
                            context,
                            hintText:
                            'Selecciona el tipo de cuenta',
                            icon: Icons.badge_outlined,
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'ADMINISTRACION',
                              child: Text('Administración'),
                            ),
                            DropdownMenuItem(
                              value: 'COORDINADOR',
                              child: Text('Coordinador'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value == null) return;

                            setState(() {
                              selectedRole = value;

                              if (selectedRole !=
                                  'COORDINADOR') {
                                selectedCourseIds.clear();
                              }
                            });
                          },
                        ),
                        buildCourseSelector(context),
                        const SizedBox(height: 25),
                        _sectionTitle(
                          'Cuenta externa',
                          Icons.link_rounded,
                        ),
                        const SizedBox(height: 7),
                        Text(
                          'Puedes asociar una cuenta Google para utilizar servicios externos.',
                          style: TextStyle(
                            color: mutedTextColor(context),
                            fontSize: 13,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: textColor,
                              side: BorderSide(
                                color: borderColor(context),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                BorderRadius.circular(14),
                              ),
                            ),
                            onPressed: isGoogleLoading
                                ? null
                                : seleccionarCuentaGoogle,
                            icon: isGoogleLoading
                                ? const SizedBox(
                              width: 19,
                              height: 19,
                              child:
                              CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                                : const Text(
                              'G',
                              style: TextStyle(
                                color:
                                Color(0xFF4285F4),
                                fontSize: 20,
                                fontWeight:
                                FontWeight.w800,
                              ),
                            ),
                            label: Text(
                              isGoogleLoading
                                  ? 'Conectando con Google...'
                                  : googleEmail == null
                                  ? 'Asociar cuenta Google'
                                  : 'Cambiar cuenta Google',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        _googleAccountCard(context),
                        const SizedBox(height: 22),
                        if (errorMessage != null)
                          _messageBox(
                            message: errorMessage!,
                            isSuccess: false,
                          ),
                        if (successMessage != null)
                          _messageBox(
                            message: successMessage!,
                            isSuccess: true,
                          ),
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                BorderRadius.circular(14),
                              ),
                            ),
                            onPressed:
                            isLoading ? null : register,
                            child: isLoading
                                ? const SizedBox(
                              width: 22,
                              height: 22,
                              child:
                              CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: Colors.white,
                              ),
                            )
                                : const Text(
                              'Crear cuenta',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight:
                                FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Center(
                          child: TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                            },
                            child: const Text(
                              'Volver al inicio de sesión',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _decorativeCircle(
      double size,
      Color color,
      ) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}