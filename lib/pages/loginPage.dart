import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:learnapp/main.dart';
import 'package:learnapp/pages/dashboardPage.dart'
as dashboard_page;

import 'package:learnapp/pages/registroPage.dart'
as registro_page;

import '../config/api_config.dart';


class LoginPageST extends StatefulWidget {
  const LoginPageST({super.key});

  @override
  State<LoginPageST> createState() => LoginState();
}

class LoginState extends State<LoginPageST> {
  final TextEditingController emailController =
  TextEditingController();

  final TextEditingController passController =
  TextEditingController();

  final FlutterSecureStorage secureStorage =
  const FlutterSecureStorage();

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );

  bool isLoading = false;
  bool isGoogleLoading = false;
  bool showPassword = false;

  String? errorMessage;

  bool get isDark =>
      Theme.of(context).brightness == Brightness.dark;

  Color get primaryColor => isDark
      ? const Color(0xFF8B9CFF)
      : const Color(0xFF536DFE);

  Color get backgroundColor => isDark
      ? const Color(0xFF0C111D)
      : const Color(0xFFF5F7FB);

  Color get cardColor => isDark
      ? const Color(0xFF151C2B)
      : Colors.white;

  Color get textColor => isDark
      ? Colors.white
      : const Color(0xFF172033);

  Color borderColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF2A2F3A)
        : const Color(0xFFD7DEE8);
  }

  Color mutedTextColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? Colors.white.withOpacity(0.7)
        : Colors.black.withOpacity(0.65);
  }

  @override
  void dispose() {
    emailController.dispose();
    passController.dispose();
    super.dispose();
  }

  Future<void> login() async {
    final email = emailController.text.trim();
    final password = passController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        errorMessage = 'Introduce el email y la contraseña';
      });
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final url = Uri.parse(ApiConfig.authLogin);

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final token = data['token'];

        if (token == null || token.toString().isEmpty) {
          setState(() {
            errorMessage =
            'La respuesta no contiene un token válido';
          });
          return;
        }

        await secureStorage.write(
          key: 'jwt',
          value: token.toString(),
        );

        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const dashboard_page.Maindashboard(),
          ),
        );
      } else if (response.statusCode == 401) {
        setState(() {
          errorMessage = 'Credenciales incorrectas';
        });
      } else {
        setState(() {
          errorMessage =
          'Error al iniciar sesión (${response.statusCode})';
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'No se pudo conectar con el servidor';
      });
    } finally {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> vincularGoogle() async {
    setState(() {
      isGoogleLoading = true;
      errorMessage = null;
    });

    try {
      final jwt = await secureStorage.read(key: 'jwt');

      if (jwt == null || jwt.isEmpty) {
        setState(() {
          errorMessage =
          'Primero inicia sesión con tu usuario y contraseña para vincular Google';
        });
        return;
      }

      await _googleSignIn.signOut();

      final GoogleSignInAccount? account =
      await _googleSignIn.signIn();

      if (account == null) {
        setState(() {
          errorMessage =
          'Se canceló el acceso con Google';
        });
        return;
      }

      final response = await http.post(
        Uri.parse(ApiConfig.authGoogleLink),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwt',
        },
        body: jsonEncode({
          'googleId': account.id,
          'googleEmail': account.email,
        }),
      );

      if (response.statusCode == 200) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Cuenta Google vinculada correctamente',
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else if (response.statusCode == 401) {
        setState(() {
          errorMessage =
          'Tu sesión ha caducado. Vuelve a iniciar sesión';
        });
      } else if (response.statusCode == 409) {
        setState(() {
          errorMessage = response.body.isNotEmpty
              ? response.body
              : 'Esa cuenta Google ya está vinculada a otro usuario';
        });
      } else {
        setState(() {
          errorMessage = response.body.isNotEmpty
              ? response.body
              : 'Error al vincular Google (${response.statusCode})';
        });
      }
    } catch (e) {
      setState(() {
        errorMessage =
        'No se pudo completar la vinculación con Google';
      });
    } finally {
      if (!mounted) return;

      setState(() {
        isGoogleLoading = false;
      });
    }
  }

  InputDecoration fieldDecoration(
      BuildContext context, {
        required String hintText,
        required IconData icon,
        Widget? suffixIcon,
      }) {
    final isDark =
        Theme.of(context).brightness == Brightness.dark;

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: Stack(
        children: [
          Positioned(
            top: -100,
            right: -80,
            child: _decorativeCircle(
              240,
              primaryColor.withOpacity(.12),
            ),
          ),
          Positioned(
            bottom: -130,
            left: -100,
            child: _decorativeCircle(
              280,
              Colors.deepPurple.withOpacity(.08),
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
                  56,
                  24,
                  32,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 470,
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
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: primaryColor.withOpacity(.13),
                              borderRadius:
                              BorderRadius.circular(20),
                            ),
                            child: Icon(
                              Icons.folder_special_rounded,
                              size: 32,
                              color: primaryColor,
                            ),
                          ),
                        ),
                        const SizedBox(height: 22),
                        Center(
                          child: Text(
                            'Bienvenido de nuevo',
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
                            'Accede a tu cuenta para continuar',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: mutedTextColor(context),
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const SizedBox(height: 30),
                        Text(
                          'Email',
                          style: TextStyle(
                            color: textColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 9),
                        TextField(
                          controller: emailController,
                          keyboardType:
                          TextInputType.emailAddress,
                          decoration: fieldDecoration(
                            context,
                            hintText: 'Introduce tu email',
                            icon: Icons.mail_outline_rounded,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'Password',
                          style: TextStyle(
                            color: textColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 9),
                        TextField(
                          controller: passController,
                          obscureText: !showPassword,
                          decoration: fieldDecoration(
                            context,
                            hintText:
                            'Introduce tu contraseña',
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
                        const SizedBox(height: 16),
                        if (errorMessage != null)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.redAccent
                                  .withOpacity(.1),
                              borderRadius:
                              BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.redAccent
                                    .withOpacity(.25),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.error_outline_rounded,
                                  size: 19,
                                  color: Colors.redAccent,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    errorMessage!,
                                    style: const TextStyle(
                                      color: Colors.redAccent,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 22),
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
                            isLoading ? null : login,
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
                              'Sign in',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight:
                                FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 22),
                        Row(
                          children: [
                            Expanded(
                              child: Divider(
                                color: borderColor(context),
                              ),
                            ),
                            Padding(
                              padding:
                              const EdgeInsets.symmetric(
                                horizontal: 14,
                              ),
                              child: Text(
                                'o continúa con',
                                style: TextStyle(
                                  color:
                                  mutedTextColor(context),
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Divider(
                                color: borderColor(context),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
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
                                : vincularGoogle,
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
                                  ? 'Vinculando cuenta Google...'
                                  : 'Vincular cuenta Google',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Primero entra con tu usuario y contraseña. Después puedes vincular la cuenta Google que usarás para servicios externos.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: mutedTextColor(context),
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Center(
                          child: TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                  const registro_page.RegisterPage(),
                                ),
                              );
                            },
                            child: const Text(
                              'Crear cuenta',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
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