import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:learnapp/main.dart';

import '../model/course.dart';

const Color accentColor = Color(0xFF3ECF8E);

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
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

  String? errorMessage;
  String? successMessage;

  String? googleId;
  String? googleEmail;
  String? googleDisplayName;

  String selectedRole = 'ADMINISTRACION';
  List<Course> availableCourses = [];
  List<int> selectedCourseIds = [];

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
        Uri.parse('http://localhost:8080/api/public/courses'),
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
              .map((e) => Course.fromJson(e as Map<String, dynamic>))
              .toList();

          setState(() {
            availableCourses = courses;
          });
        } else {
          setState(() {
            errorMessage = 'La respuesta de cursos no tiene formato de lista';
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
      final GoogleSignInAccount? account = await _googleSignIn.signIn();

      if (account == null) {
        setState(() {
          errorMessage = 'Se canceló la selección de cuenta Google';
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
          usernameController.text = account.displayName!.trim();
        }

        successMessage = 'Cuenta Google seleccionada correctamente';
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
      successMessage = 'Cuenta Google desvinculada del formulario';
    });
  }

  void toggleCourseSelection(int courseId, bool selected) {
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
    final confirmPassword = confirmPasswordController.text.trim();

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
        errorMessage = 'La contraseña debe tener al menos 4 caracteres';
        successMessage = null;
      });
      return;
    }

    if (selectedRole == 'COORDINADOR' && selectedCourseIds.isEmpty) {
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
        Uri.parse('http://localhost:8080/api/auth/register'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'username': username,
          'email': email,
          'password': password,
          'role': selectedRole,
          'courseIds': selectedRole == 'COORDINADOR' ? selectedCourseIds : [],
          'googleId': googleId,
          'googleEmail': googleEmail,
          'googleLinked': googleEmail != null && googleEmail!.isNotEmpty,
          'authProvider': googleEmail != null && googleEmail!.isNotEmpty
              ? 'LOCAL_GOOGLE'
              : 'LOCAL',
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        setState(() {
          successMessage = googleEmail != null
              ? 'Usuario registrado y cuenta Google asociada correctamente'
              : 'Usuario registrado correctamente';
          errorMessage = null;
        });

        await Future.delayed(const Duration(milliseconds: 1200));

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
        errorMessage = 'No se pudo conectar con el servidor';
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
        const SizedBox(height: 16),
        const Text('Ciclos asignados'),
        const SizedBox(height: 8),
        Text(
          'Selecciona los ciclos de los que será coordinador',
          style: TextStyle(
            color: mutedTextColor(context),
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 12),
        if (isLoadingCourses)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: LinearProgressIndicator(),
          )
        else if (availableCourses.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: borderColor(context)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'No hay ciclos disponibles',
              style: TextStyle(color: mutedTextColor(context)),
            ),
          )
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: borderColor(context)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: availableCourses.map((course) {
                final selected = selectedCourseIds.contains(course.id);
                final label = course.acronym.trim().isNotEmpty
                    ? '${course.acronym} · ${course.name}'
                    : course.name;

                return FilterChip(
                  label: Text(label),
                  selected: selected,
                  selectedColor: accentColor.withOpacity(0.25),
                  checkmarkColor: Colors.black,
                  side: BorderSide(color: borderColor(context)),
                  onSelected: (value) {
                    toggleCourseSelection(course.id, value);
                  },
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Registro'),
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
                              'Crear nueva cuenta',
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
                      constraints: const BoxConstraints(maxWidth: 520),
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
                              'Register',
                              style: TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Crea una cuenta e indica si pertenece a administración o a coordinación. Si es coordinador, podrás asignarle sus ciclos desde el alta.',
                              style: TextStyle(
                                color: mutedTextColor(context),
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 24),
                            const Text('Username'),
                            const SizedBox(height: 8),
                            TextField(
                              controller: usernameController,
                              decoration: const InputDecoration(
                                hintText: 'Introduce tu usuario',
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text('Email'),
                            const SizedBox(height: 8),
                            TextField(
                              controller: emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: const InputDecoration(
                                hintText: 'Introduce tu email',
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text('Password'),
                            const SizedBox(height: 8),
                            TextField(
                              controller: passwordController,
                              obscureText: true,
                              decoration: const InputDecoration(
                                hintText: 'Introduce tu contraseña',
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text('Confirmar password'),
                            const SizedBox(height: 8),
                            TextField(
                              controller: confirmPasswordController,
                              obscureText: true,
                              decoration: const InputDecoration(
                                hintText: 'Repite tu contraseña',
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text('Tipo de cuenta'),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              value: selectedRole,
                              decoration: const InputDecoration(
                                hintText: 'Selecciona el tipo de cuenta',
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
                                  if (selectedRole != 'COORDINADOR') {
                                    selectedCourseIds.clear();
                                  }
                                });
                              },
                            ),
                            buildCourseSelector(context),
                            const SizedBox(height: 18),
                            Row(
                              children: [
                                Expanded(
                                  child: Divider(color: borderColor(context)),
                                ),
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 12),
                                  child: Text('Google'),
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
                                onPressed: isGoogleLoading
                                    ? null
                                    : seleccionarCuentaGoogle,
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
                                      ? 'Conectando con Google...'
                                      : googleEmail == null
                                      ? 'Asociar cuenta Google'
                                      : 'Cambiar cuenta Google',
                                ),
                              ),
                            ),
                            if (googleEmail != null) ...[
                              const SizedBox(height: 12),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  border: Border.all(color: borderColor(context)),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Cuenta Google seleccionada',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(googleDisplayName ?? ''),
                                    Text(
                                      googleEmail!,
                                      style: TextStyle(
                                        color: mutedTextColor(context),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: TextButton(
                                        onPressed: quitarCuentaGoogle,
                                        child: const Text('Quitar'),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 16),
                            if (errorMessage != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Text(
                                  errorMessage!,
                                  style: const TextStyle(
                                    color: Colors.redAccent,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            if (successMessage != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Text(
                                  successMessage!,
                                  style: const TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
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
                                onPressed: isLoading ? null : register,
                                child: isLoading
                                    ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    color: Colors.black,
                                  ),
                                )
                                    : const Text(
                                  'Crear cuenta',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
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
                                child: const Text('Volver al login'),
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