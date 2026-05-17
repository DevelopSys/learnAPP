import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:learnapp/main.dart';
import 'package:learnapp/pages/dashboardPage.dart';
import 'package:learnapp/pages/registroPage.dart';


class LoginPageST extends StatefulWidget {
  const LoginPageST({super.key});

  @override
  State<LoginPageST> createState() => LoginState();
}

class LoginState extends State<LoginPageST> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passController = TextEditingController();
  final FlutterSecureStorage secureStorage = const FlutterSecureStorage();

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );

  bool isLoading = false;
  bool isGoogleLoading = false;
  String? errorMessage;

  Color surfaceColor(BuildContext context) =>
      Theme.of(context).colorScheme.surface;

  Color borderColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF2A2F3A)
          : const Color(0xFFD7DEE8);

  Color mutedTextColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? Colors.white.withOpacity(0.7)
          : Colors.black.withOpacity(0.65);

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
      final url = Uri.parse('http://localhost:8080/api/auth/login');

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
            errorMessage = 'La respuesta no contiene un token válido';
          });
          return;
        }

        await secureStorage.write(key: 'jwt', value: token.toString());

        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const Maindashboard()),
        );
      } else if (response.statusCode == 401) {
        setState(() {
          errorMessage = 'Credenciales incorrectas';
        });
      } else {
        setState(() {
          errorMessage = 'Error al iniciar sesión (${response.statusCode})';
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
      final GoogleSignInAccount? account = await _googleSignIn.signIn();

      if (account == null) {
        setState(() {
          errorMessage = 'Se canceló el acceso con Google';
        });
        return;
      }

      final response = await http.post(
        Uri.parse('http://localhost:8080/api/auth/google/link'),
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
            content: Text('Cuenta Google vinculada correctamente'),
            backgroundColor: Colors.green,
          ),
        );
      } else if (response.statusCode == 401) {
        setState(() {
          errorMessage = 'Tu sesión ha caducado. Vuelve a iniciar sesión';
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
        errorMessage = 'No se pudo completar la vinculación con Google';
      });
    } finally {
      if (!mounted) return;
      setState(() {
        isGoogleLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            onPressed: () {
              MyApp.of(context).toggleTheme();
            },
            icon: Icon(
              isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            ),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 900;

          return Row(
            children: [
              if (isDesktop)
                Expanded(
                  child: Column(
                    children: [
                      const Padding(padding: EdgeInsets.all(24)),
                      const Expanded(
                        child: Center(
                          child: Align(
                            alignment: Alignment.center,
                            child: Text(
                              'Sistema gestor de documentos',
                              style: TextStyle(
                                fontSize: 42,
                                fontWeight: FontWeight.w700,
                                height: 1.2,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Image.asset('assets/images/logo.jpeg'),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Container(
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          color: surfaceColor(context),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: borderColor(context)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Sign in',
                              style: TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Accede a tu cuenta para continuar',
                              style: TextStyle(
                                color: mutedTextColor(context),
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 24),
                            const Text('Email'),
                            const SizedBox(height: 8),
                            TextField(
                              controller: emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: const InputDecoration(
                                hintText: 'Introduce tu mail',
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text('Password'),
                            const SizedBox(height: 8),
                            TextField(
                              controller: passController,
                              obscureText: true,
                              decoration: const InputDecoration(
                                hintText: 'Introduce tu pass',
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (errorMessage != null)
                              Text(
                                errorMessage!,
                                style: const TextStyle(
                                  color: Colors.redAccent,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: accentColor,
                                  foregroundColor: Colors.black,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: isLoading ? null : login,
                                child: isLoading
                                    ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.4,
                                    color: Colors.black,
                                  ),
                                )
                                    : const Text(
                                  'Sign in',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: Divider(color: borderColor(context)),
                                ),
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 12),
                                  child: Text('o'),
                                ),
                                Expanded(
                                  child: Divider(color: borderColor(context)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  side: BorderSide(color: borderColor(context)),
                                ),
                                onPressed: isGoogleLoading ? null : vincularGoogle,
                                icon: isGoogleLoading
                                    ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                                    : const Icon(Icons.account_circle_outlined),
                                label: Text(
                                  isGoogleLoading
                                      ? 'Vinculando cuenta Google...'
                                      : 'Vincular cuenta Google',
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Primero entra con tu usuario y contraseña. Después puedes vincular la cuenta Google que usarás para servicios externos.',
                              style: TextStyle(
                                color: mutedTextColor(context),
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Center(
                              child: TextButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const RegisterPage()),
                                  );
                                },
                                child: const Text('Crear cuenta'),
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
          );
        },
      ),
    );
  }
}