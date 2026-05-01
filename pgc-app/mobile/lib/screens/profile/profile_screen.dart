import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pgc_app/providers/auth_provider.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final member = auth.member;

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Profil'),
      ),
      body: member == null
          ? const Center(child: CircularProgressIndicator(color: Colors.redAccent))
          : Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    member.fullName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(member.email, style: const TextStyle(color: Colors.white70)),
                  const SizedBox(height: 24),
                  Text('Rôle : ${member.role}', style: const TextStyle(color: Colors.white70)),
                  const SizedBox(height: 8),
                  Text(
                    'Abonnement : ${member.subscriptionStatus}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                      ),
                      onPressed: () => auth.logout(),
                      child: const Text('Se déconnecter'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}