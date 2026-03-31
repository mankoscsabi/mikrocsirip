import { Component, inject, OnInit, signal } from '@angular/core';
import { FormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import { RouterLink } from '@angular/router';
import { CommonModule } from '@angular/common';
import { PostService } from '../../core/services/api.service';
import { AuthService } from '../../core/services/auth.service';
import { Post } from '../../shared/models/models';

@Component({
  selector: 'app-feed',
  standalone: true,
  imports: [ReactiveFormsModule, RouterLink, CommonModule],
  template: `
    <div class="feed">
      <div class="compose-card">
        <div class="compose-header">
          <span class="avatar">{{ auth.currentUser()?.username?.[0]?.toUpperCase() }}</span>
          <form [formGroup]="postForm" (ngSubmit)="createPost()" class="compose-form">
            <textarea formControlName="content" placeholder="Mi jár a fejedben?" rows="3"
              (input)="updateCount()"></textarea>
            <div class="compose-footer">
              <span class="char-count" [class.over]="charCount > 280">{{ charCount }}/280</span>
              <button type="submit" [disabled]="postForm.invalid || creating" class="btn-post">
                {{ creating ? 'Küldés...' : 'Csiripelj' }}
              </button>
            </div>
          </form>
        </div>
      </div>

      @if (feedError()) {
        <div class="error-banner">
          Nem sikerült betölteni a feedet.
          <button (click)="reload()">Újra</button>
        </div>
      }

      @for (post of posts(); track post.id) {
        <div class="post-card">
          <a [routerLink]="['/profile', post.author.username]" class="post-avatar">
            {{ post.author.username[0].toUpperCase() }}
          </a>
          <div class="post-body">
            <div class="post-header">
              <a [routerLink]="['/profile', post.author.username]" class="post-username">
                {{ post.author.username }}
              </a>
              <span class="post-time">{{ post.createdAt | date:'shortTime' }}</span>
            </div>
            <p class="post-content">{{ post.content }}</p>
            <div class="post-actions">
              <button class="btn-like" [class.liked]="post.isLikedByMe" (click)="toggleLike(post)">
                {{ post.isLikedByMe ? 'Tetszik' : 'Tetszik' }} {{ post.likeCount }}
              </button>
              @if (post.author.id === auth.currentUser()?.id) {
                <button class="btn-delete" (click)="deletePost(post)">Törlés</button>
              }
            </div>
          </div>
        </div>
      }

      @if (posts().length === 0 && !loading) {
        <div class="empty-state">
          <p>Még nincs csiripeled. Kövesd ismerőseidet, vagy csiripelj valamit!</p>
        </div>
      }

      @if (loading) {
        <div class="loading">Betöltés...</div>
      }

      @if (hasMore()) {
        <button class="btn-load-more" (click)="loadMore()" [disabled]="loading">
          Több betöltése
        </button>
      }
    </div>
  `,
  styles: [`
    .feed { display: flex; flex-direction: column; gap: 1rem; }

    .compose-card {
      background: #ffffff; border: 1px solid #e0e0d8;
      border-radius: 14px; padding: 1.25rem;
      box-shadow: 0 1px 4px rgba(0,0,0,0.04);
    }
    .compose-header { display: flex; gap: 1rem; }
    .avatar {
      width: 42px; height: 42px; border-radius: 50%;
      background: #e8e8e0; color: #555550;
      display: flex; align-items: center; justify-content: center;
      font-weight: 700; flex-shrink: 0; font-size: 1rem;
    }
    .compose-form { flex: 1; }
    textarea {
      width: 100%; background: transparent; border: none;
      color: #1a1a1a; font-size: 1rem; font-family: 'DM Sans', sans-serif;
      resize: none; outline: none; line-height: 1.6; box-sizing: border-box;
    }
    textarea::placeholder { color: #b0b0a8; }
    .compose-footer {
      display: flex; justify-content: flex-end; align-items: center;
      gap: 1rem; margin-top: 0.75rem;
      border-top: 1px solid #f0f0e8; padding-top: 0.75rem;
    }
    .char-count { font-size: 0.8rem; color: #b0b0a8; }
    .char-count.over { color: #dc2626; }
    .btn-post {
      background: #2a2a2a; border: none; color: #fff;
      padding: 0.5rem 1.25rem; border-radius: 20px;
      font-weight: 600; cursor: pointer; font-size: 0.9rem;
      font-family: 'DM Sans', sans-serif; transition: background 0.2s;
    }
    .btn-post:hover { background: #1a1a1a; }
    .btn-post:disabled { background: #c8c8c0; cursor: not-allowed; }

    .post-card {
      background: #ffffff; border: 1px solid #e0e0d8;
      border-radius: 14px; padding: 1.25rem;
      display: flex; gap: 1rem;
      box-shadow: 0 1px 4px rgba(0,0,0,0.04);
      transition: box-shadow 0.2s;
    }
    .post-card:hover { box-shadow: 0 2px 8px rgba(0,0,0,0.08); }
    .post-avatar {
      width: 42px; height: 42px; border-radius: 50%;
      background: #f0f0e8; color: #888880;
      display: flex; align-items: center; justify-content: center;
      font-weight: 700; flex-shrink: 0; text-decoration: none; font-size: 1rem;
    }
    .post-body { flex: 1; min-width: 0; }
    .post-header { display: flex; align-items: baseline; gap: 0.6rem; margin-bottom: 0.4rem; }
    .post-username {
      color: #1a1a1a; font-weight: 600; text-decoration: none; font-size: 0.95rem;
    }
    .post-username:hover { color: #555550; }
    .post-time { color: #b0b0a8; font-size: 0.8rem; }
    .post-content { color: #3a3a3a; line-height: 1.6; margin: 0 0 0.75rem; word-break: break-word; }
    .post-actions { display: flex; gap: 1rem; }
    .btn-like {
      background: none; border: none; color: #b0b0a8;
      cursor: pointer; font-size: 0.9rem; padding: 0; transition: color 0.2s;
    }
    .btn-like:hover, .btn-like.liked { color: #e11d48; }
    .btn-delete {
      background: none; border: none; color: #c8c8c0;
      cursor: pointer; font-size: 0.8rem; padding: 0; transition: color 0.2s;
    }
    .btn-delete:hover { color: #dc2626; }

    .empty-state {
      text-align: center; color: #b0b0a8; padding: 3rem;
      background: #fff; border: 1px dashed #e0e0d8; border-radius: 14px;
    }
    .loading { text-align: center; color: #b0b0a8; padding: 2rem; }
    .error-banner {
      background: #fff5f5; border: 1px solid #fecaca; color: #dc2626;
      padding: 0.75rem 1rem; border-radius: 10px;
      display: flex; justify-content: space-between; align-items: center;
    }
    .error-banner button {
      background: none; border: 1px solid #dc2626; color: #dc2626;
      padding: 0.25rem 0.75rem; border-radius: 6px; cursor: pointer; font-size: 0.85rem;
    }
    .btn-load-more {
      width: 100%; padding: 0.85rem;
      background: #fff; border: 1px solid #e0e0d8;
      color: #888880; border-radius: 10px; cursor: pointer;
      font-family: 'DM Sans', sans-serif; font-size: 0.9rem;
      transition: all 0.2s;
    }
    .btn-load-more:hover:not(:disabled) { border-color: #999990; color: #1a1a1a; }
    .btn-load-more:disabled { opacity: 0.5; cursor: not-allowed; }
  `]
})
export class FeedComponent implements OnInit {
  private postService = inject(PostService);
  auth = inject(AuthService);
  private fb = inject(FormBuilder);

  posts = signal<Post[]>([]);
  hasMore = signal(false);
  loading = false;
  creating = false;
  page = 1;
  charCount = 0;
  feedError = signal(false);

  postForm = this.fb.group({
    content: ['', [Validators.required, Validators.maxLength(280)]]
  });

  ngOnInit() { this.loadFeed(); }

  updateCount() {
    this.charCount = this.postForm.value.content?.length ?? 0;
  }

  reload() {
    this.page = 1;
    this.posts.set([]);
    this.feedError.set(false);
    this.loadFeed();
  }

  loadFeed() {
    this.loading = true;
    this.postService.getFeed(this.page).subscribe({
      next: (res) => {
        this.posts.update(p => this.page === 1 ? res.posts : [...p, ...res.posts]);
        this.hasMore.set(this.posts().length < res.totalCount);
        this.loading = false;
        this.feedError.set(false);
      },
      error: () => {
        this.loading = false;
        this.feedError.set(true);
      }
    });
  }

  loadMore() { this.page++; this.loadFeed(); }

  createPost() {
    const content = this.postForm.value.content?.trim();
    if (!content) return;
    this.creating = true;
    this.postService.createPost(content).subscribe({
      next: (post) => {
        this.posts.update(p => [post, ...p]);
        this.postForm.reset();
        this.charCount = 0;
        this.creating = false;
      },
      error: () => { this.creating = false; }
    });
  }

  toggleLike(post: Post) {
    this.postService.likePost(post.id).subscribe({
      next: (res) => {
        this.posts.update(posts => posts.map(p =>
          p.id === post.id
            ? { ...p, isLikedByMe: res.liked, likeCount: p.likeCount + (res.liked ? 1 : -1) }
            : p
        ));
      },
      error: () => {}
    });
  }

  deletePost(post: Post) {
    if (!confirm('Biztosan törlöd ezt a csiripet?')) return;
    this.postService.deletePost(post.id).subscribe({
      next: () => this.posts.update(posts => posts.filter(p => p.id !== post.id)),
      error: () => {}
    });
  }
}
