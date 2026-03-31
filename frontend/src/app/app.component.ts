import { Component, inject } from '@angular/core';
import { RouterOutlet, RouterLink } from '@angular/router';
import { AuthService } from './core/services/auth.service';
import { CommonModule } from '@angular/common';

@Component({
 selector: 'app-root',
 standalone: true,
 imports: [RouterOutlet, RouterLink, CommonModule],
 template: `
 <div class="app-shell">
 @if (auth.isLoggedIn()) {
 <nav class="navbar">
 <a routerLink="/feed" class="brand">
 <span class="brand-icon"></span>
 <span class="brand-text">MikroCsirip</span>
 </a>
 <div class="nav-links">
 <a routerLink="/feed">Feed</a>
 <a [routerLink]="['/profile', auth.currentUser()?.username]">
 {{ auth.currentUser()?.username }}
 </a>
 <button (click)="auth.logout()" class="btn-logout">Kilépés</button>
 </div>
 </nav>
 }
 <main class="main-content">
 <router-outlet />
 </main>
 </div>
 `,
 styles: [`
 .app-shell {
 min-height: 100vh;
 background: #f5f5f0;
 color: #1a1a1a;
 font-family: 'DM Sans', sans-serif;
 }
 .navbar {
 display: flex;
 justify-content: space-between;
 align-items: center;
 padding: 0.9rem 2rem;
 border-bottom: 1px solid #e0e0d8;
 position: sticky;
 top: 0;
 background: rgba(245,245,240,0.95);
 backdrop-filter: blur(10px);
 z-index: 100;
 }
 .brand {
 display: flex;
 align-items: center;
 gap: 0.5rem;
 text-decoration: none;
 }
 .brand-icon { font-size: 1.4rem; }
 .brand-text {
 font-size: 1.2rem;
 font-weight: 700;
 color: #2a2a2a;
 letter-spacing: -0.5px;
 font-family: 'DM Serif Display', serif;
 }
 .nav-links {
 display: flex;
 gap: 1.5rem;
 align-items: center;
 }
 .nav-links a {
 color: #666660;
 text-decoration: none;
 font-size: 0.9rem;
 font-weight: 500;
 transition: color 0.2s;
 }
 .nav-links a:hover { color: #1a1a1a; }
 .btn-logout {
 background: none;
 border: 1px solid #d0d0c8;
 color: #666660;
 padding: 0.35rem 0.9rem;
 border-radius: 6px;
 cursor: pointer;
 font-size: 0.85rem;
 font-family: 'DM Sans', sans-serif;
 transition: all 0.2s;
 }
 .btn-logout:hover {
 border-color: #999990;
 color: #1a1a1a;
 }
 .main-content {
 max-width: 680px;
 margin: 0 auto;
 padding: 2rem 1rem;
 }
 `]
})
export class AppComponent {
 auth = inject(AuthService);
}
