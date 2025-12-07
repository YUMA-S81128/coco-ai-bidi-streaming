import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ImageDisplay extends StatelessWidget {
  const ImageDisplay({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('image_jobs')
          .where('userId', isEqualTo: user.uid)
          .orderBy('createdAt', descending: true)
          .limit(1)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          // Ignore permission errors initially as rules might not be set up
          return Center(child: Text('Waiting for image... (Error: ${snapshot.error})'));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No images yet. Ask Gemini to draw something!'));
        }

        final doc = snapshot.data!.docs.first;
        final data = doc.data() as Map<String, dynamic>;
        final status = data['status'] as String?;
        final imageUrl = data['imageUrl'] as String?;
        final prompt = data['prompt'] as String?;
        final error = data['error'] as String?;

        if (status == 'pending' || status == 'processing') {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text('Generating image for: "$prompt"...'),
              ],
            ),
          );
        }

        if (status == 'completed' && imageUrl != null) {
          return Column(
            children: [
              Expanded(
                child: Image.network(
                  imageUrl,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(child: CircularProgressIndicator());
                  },
                  errorBuilder: (context, error, stackTrace) => const Center(child: Icon(Icons.error)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text('Prompt: "$prompt"'),
              ),
            ],
          );
        }

        if (status == 'failed') {
           return Center(child: Text('Failed to generate image: $error'));
        }

        return const SizedBox.shrink();
      },
    );
  }
}
