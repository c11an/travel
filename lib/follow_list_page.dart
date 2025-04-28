import 'package:flutter/material.dart';

class FollowListPage extends StatelessWidget {
  final String title;
  final List<String> userList;

  const FollowListPage({super.key, required this.title, required this.userList});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: userList.isEmpty
          ? const Center(child: Text('目前沒有任何人'))
          : ListView.builder(
              itemCount: userList.length,
              itemBuilder: (context, index) {
                final user = userList[index];
                return TweenAnimationBuilder(
                  tween: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero),
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                  builder: (context, offset, child) {
                    return Transform.translate(
                      offset: offset * 50,
                      child: FadeTransition(
                        opacity: AlwaysStoppedAnimation(1 - offset.dx),
                        child: ListTile(
                          leading: const CircleAvatar(child: Icon(Icons.person)),
                          title: Text(user),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
