import { Component, inject } from '@angular/core';
import { FormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import { Router, RouterLink } from '@angular/router';
import { AuthService } from '../../core/services/auth.service';
import { CommonModule } from '@angular/common';

@Component({
 selector: 'app-register',
 standalone: true,
 imports: [ReactiveFormsModule, RouterLink, CommonModule],
 template: `
 <div class="auth-card">
 <div class="auth-header">
 <span class="auth-icon"></span>
 <h1>MikroCsirip</h1>
 <p class="subtitle">Hozz létre egy fiókot</p>
 </div>

 <form [formGroup]="form" (ngSubmit)="submit()">
 <div class="field">
 <label>Felhasználónév</label>
 <input type="text" formControlName="username" placeholder="pl. kovacsj" />
 </div>
 <div class="field">
 <label>Email</label>
 <input type="email" formControlName="email" placeholder="te@example.com" />
 </div>
 <div class="field">
 <label>Jelszó</label>
 <input type="password" formControlName="password" placeholder="Min. 6 karakter" />
 </div>

 @if (error) {
 <div class="error">{{ error }}</div>
 }

 <button type="submit" [disabled]="loading || form.invalid" class="btn-primary">
 {{ loading ? 'Regisztráció...' : 'Regisztráció' }}
 </button>
 </form>

 <p class="switch-link">Már van fiókod? <a routerLink="/login">Jelentkezz be</a></p>
 </div>
 `,
 styles: [`
 .auth-card {
 max-width: 420px;
 margin: 4rem auto;
 padding: 2.5rem;
 background: #ffffff;
 border: 1px solid #e0e0d8;
 border-radius: 16px;
 box-shadow: 0 2px 16px rgba(0,0,0,0.06);
 }
 .auth-header { text-align: center; margin-bottom: 2rem; }
 .auth-icon { font-size: 2.5rem; display: block; margin-bottom: 0.5rem; }
 h1 {
 color: #1a1a1a;
 font-size: 1.8rem;
 margin: 0 0 0.4rem;
 font-family: 'DM Serif Display', serif;
 font-weight: 400;
 }
 .subtitle { color: #999990; margin: 0; font-size: 0.9rem; }
 .field { margin-bottom: 1.2rem; }
 label { display: block; font-size: 0.85rem; color: #555550; margin-bottom: 0.4rem; font-weight: 500; }
 input {
 width: 100%;
 padding: 0.75rem 1rem;
 background: #fafafa;
 border: 1px solid #e0e0d8;
 border-radius: 8px;
 color: #1a1a1a;
 font-size: 0.95rem;
 font-family: 'DM Sans', sans-serif;
 box-sizing: border-box;
 transition: border-color 0.2s;
 }
 input:focus { outline: none; border-color: #999990; background: #fff; }
 .btn-primary {
 width: 100%;
 padding: 0.85rem;
 background: #2a2a2a;
 border: none;
 border-radius: 8px;
 color: #ffffff;
 font-weight: 600;
 font-size: 0.95rem;
 font-family: 'DM Sans', sans-serif;
 cursor: pointer;
 margin-top: 0.5rem;
 transition: background 0.2s;
 }
 .btn-primary:hover { background: #1a1a1a; }
 .btn-primary:disabled { background: #c8c8c0; cursor: not-allowed; }
 .error {
 background: #fff5f5;
 border: 1px solid #fecaca;
 color: #dc2626;
 padding: 0.75rem;
 border-radius: 8px;
 font-size: 0.85rem;
 margin-bottom: 1rem;
 }
 .switch-link { text-align: center; color: #999990; font-size: 0.85rem; margin-top: 1.5rem; }
 .switch-link a { color: #2a2a2a; text-decoration: none; font-weight: 600; }
 .switch-link a:hover { text-decoration: underline; }
 `]
})
export class RegisterComponent {
 private auth = inject(AuthService);
 private router = inject(Router);
 private fb = inject(FormBuilder);

 form = this.fb.group({
 username: ['', [Validators.required, Validators.minLength(3), Validators.maxLength(50)]],
 email: ['', [Validators.required, Validators.email]],
 password: ['', [Validators.required, Validators.minLength(6)]]
 });

 loading = false;
 error = '';

 submit() {
 if (this.form.invalid) return;
 this.loading = true;
 this.error = '';
 const { username, email, password } = this.form.value;

 this.auth.register({ username: username!, email: email!, password: password! }).subscribe({
 next: () => this.router.navigate(['/feed']),
 error: (err) => {
 this.error = err.status === 409 ? 'Ez az email vagy felhasználónév már foglalt.' : 'Hiba történt.';
 this.loading = false;
 }
 });
 }
}
