import { Component, inject, OnInit, signal } from '@angular/core';
import { ActivatedRoute, RouterLink } from '@angular/router';
import { CommonModule } from '@angular/common';
import { UserService, PostService } from '../../core/services/api.service';
import { AuthService } from '../../core/services/auth.service';
import { User, Post } from '../../shared/models/models';

@Component({
  selector: 'app-profile',
  standalone: true,
  imports: [CommonModule, RouterLink],
  template: `
    @if (error()) {
      <div class="error-state">{{ error() }}</div>
    } @else if (user()) {
      <div class="profile">
        <div class="profile-header">
          <div class="profile-avatar">{{ user()!.username[0].toUpperCase() }}</div>
          <div class="profile-info">
            <h2>{{ user()!.username }}</h2>
            @if (user()!.bio) { <p class="bio">{{ user()!.bio }}</p> }
            <div class="stats">
              <span><strong>{{ user()!.postCount }}</strong> csiripel</span>
              <span><strong>{{ user()!.followerCount }}</strong> követő</span>
              <span><strong>{{ user()!.followingCount }}</strong> követett</span>
            </div>
          </div>
          @if (auth.currentUser()?.id !== user()!.id) {
            <button class="btn-follow" [class.following]="isFollowing()" (click)="toggleFollow()">
              {{ isFollowing() ? 'Követed' : 'Követés' }}
            </button>
          }
        </div>

        <div class="posts-list">
          @for (post of posts(); track post.id) {
            <div class="post-card">
              <p class="post-content">{{ post.content }}</p>
              <span class="post-time">{{ post.createdAt | date:'medium' }}</span>
            </div>
          }
          @if (posts().length === 0 && !loading()) {
            <div class="empty-state">
              <p>Még nincsenek csiripelések.</p>
            </div>
          }
          @if (loading()) {
            <div class="loading">Betöltés...</div>
          }
        </div>
      </div>
    } @else {
      <div class="loading">Betöltés...</div>
    }
  `,
  styles: [`
    .profile-header {
      background: #ffffff; border: 1px solid #e0e0d8;
      border-radius: 14px; padding: 1.75rem;
      display: flex; gap: 1.25rem; align-items: flex-start;
      margin-bottom: 1.5rem;
      box-shadow: 0 1px 4px rgba(0,0,0,0.04);
    }
    .profile-avatar {
      width: 64px; height: 64px; border-radius: 50%;
      background: #e8e8e0; color: #555550;
      display: flex; align-items: center; justify-content: center;
      font-size: 1.75rem; font-weight: 700; flex-shrink: 0;
    }
    .profile-info { flex: 1; }
    .profile-info h2 { margin: 0 0 0.4rem; color: #1a1a1a; font-size: 1.3rem; font-weight: 700; }
    .bio { color: #666660; margin: 0 0 0.75rem; font-size: 0.9rem; line-height: 1.5; }
    .stats { display: flex; gap: 1.5rem; }
    .stats span { color: #888880; font-size: 0.85rem; }
    .stats strong { color: #1a1a1a; }
    .btn-follow {
      padding: 0.5rem 1.25rem; border-radius: 20px;
      border: 1px solid #2a2a2a; background: transparent;
      color: #2a2a2a; cursor: pointer; font-size: 0.9rem;
      font-weight: 600; font-family: 'DM Sans', sans-serif;
      transition: all 0.2s; white-space: nowrap; align-self: flex-start;
    }
    .btn-follow:hover, .btn-follow.following { background: #2a2a2a; color: #fff; }

    .posts-list { display: flex; flex-direction: column; gap: 1rem; }
    .post-card {
      background: #ffffff; border: 1px solid #e0e0d8;
      border-radius: 14px; padding: 1.25rem;
      box-shadow: 0 1px 4px rgba(0,0,0,0.04);
    }
    .post-content { color: #3a3a3a; line-height: 1.6; margin: 0 0 0.5rem; }
    .post-time { color: #b0b0a8; font-size: 0.8rem; }
    .empty-state {
      text-align: center; color: #b0b0a8; padding: 3rem;
      background: #fff; border: 1px dashed #e0e0d8; border-radius: 14px;
    }
    .loading { text-align: center; color: #b0b0a8; padding: 3rem; }
    .error-state {
      text-align: center; color: #dc2626; padding: 3rem;
      background: #fff5f5; border: 1px solid #fecaca; border-radius: 14px;
    }
  `]
})
export class ProfileComponent implements OnInit {
  private route = inject(ActivatedRoute);
  private userService = inject(UserService);
  private postService = inject(PostService);
  auth = inject(AuthService);

  user = signal<User | null>(null);
  posts = signal<Post[]>([]);
  isFollowing = signal(false);
  loading = signal(false);
  error = signal('');

  ngOnInit() {
    this.route.params.subscribe(p => this.loadProfile(p['username']));
  }

  loadProfile(username: string) {
    this.loading.set(true);
    this.error.set('');
    this.user.set(null);
    this.posts.set([]);

    this.userService.getProfile(username).subscribe({
      next: (u) => {
        this.user.set(u);
        // isFollowing állapot meghatározása
        const currentUser = this.auth.currentUser();
        if (currentUser && u.id !== currentUser.id) {
          // A backend visszaadja hogy követjük-e
          this.isFollowing.set((u as any).isFollowedByMe ?? false);
        }
        this.loading.set(false);
      },
      error: () => {
        this.error.set('A profil nem található.');
        this.loading.set(false);
      }
    });

    this.postService.getUserPosts(username).subscribe({
      next: (r) => this.posts.set(r.posts),
      error: () => {}
    });
  }

  toggleFollow() {
    const username = this.user()?.username;
    if (!username) return;
    this.userService.follow(username).subscribe({
      next: (res) => {
        this.isFollowing.set(res.following);
        this.user.update(u => u ? {
          ...u, followerCount: u.followerCount + (res.following ? 1 : -1)
        } : null);
      },
      error: () => {}
    });
  }
}
