import 'package:flutter/material.dart';
import 'package:learnapp/main.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

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
                      Expanded(child: Image.asset('assets/images/logo.jpeg')),
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
                            const TextField(
                              decoration: InputDecoration(
                                hintText: 'Introduce tu mail',
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text('Password'),
                            const SizedBox(height: 8),
                            const TextField(
                              obscureText: true,
                              decoration: InputDecoration(
                                hintText: 'Introduce tu pass',
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
                                onPressed: () {},
                                child: const Text(
                                  'Sign in',
                                  style: TextStyle(fontWeight: FontWeight.w600),
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
                            Center(
                              child: TextButton(
                                onPressed: () {},
                                child: const Text('¿Olvidaste la contraseña?'),
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