import { Injectable } from '@angular/core';
import { HttpClient, HttpParams } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from '../../../environments/environment';
import { FeedResponse, Post, User } from '../../shared/models/models';

@Injectable({ providedIn: 'root' })
export class PostService {
 constructor(private http: HttpClient) {}

 getFeed(page = 1, pageSize = 20): Observable<FeedResponse> {
 const params = new HttpParams().set('page', page).set('pageSize', pageSize);
 return this.http.get<FeedResponse>(`${environment.apiUrl}/posts/feed`, { params });
 }

 createPost(content: string): Observable<Post> {
 return this.http.post<Post>(`${environment.apiUrl}/posts`, { content });
 }

 likePost(postId: number): Observable<{ liked: boolean }> {
 return this.http.post<{ liked: boolean }>(`${environment.apiUrl}/posts/${postId}/like`, {});
 }

 deletePost(postId: number): Observable<void> {
 return this.http.delete<void>(`${environment.apiUrl}/posts/${postId}`);
 }

 getUserPosts(username: string, page = 1, pageSize = 20): Observable<FeedResponse> {
 const params = new HttpParams().set('page', page).set('pageSize', pageSize);
 return this.http.get<FeedResponse>(`${environment.apiUrl}/users/${username}/posts`, { params });
 }
}

@Injectable({ providedIn: 'root' })
export class UserService {
 constructor(private http: HttpClient) {}

 getProfile(username: string): Observable<User> {
 return this.http.get<User>(`${environment.apiUrl}/users/${username}`);
 }

 updateProfile(data: { bio?: string; avatarUrl?: string }): Observable<User> {
 return this.http.put<User>(`${environment.apiUrl}/users/me`, data);
 }

 follow(username: string): Observable<{ following: boolean }> {
 return this.http.post<{ following: boolean }>(`${environment.apiUrl}/users/${username}/follow`, {});
 }

 search(query: string): Observable<User[]> {
 return this.http.get<User[]>(`${environment.apiUrl}/users/search`, { params: { q: query } });
 }
}
