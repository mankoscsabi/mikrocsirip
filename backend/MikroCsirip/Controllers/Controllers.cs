using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using MikroCsirip.DTOs;
using MikroCsirip.Services;

namespace MikroCsirip.Controllers;

[ApiController]
[Route("api/[controller]")]
public class AuthController : ControllerBase
{
 private readonly IAuthService _auth;
 public AuthController(IAuthService auth) => _auth = auth;

 [HttpPost("register")]
 public async Task<IActionResult> Register(RegisterRequest request)
 {
 var result = await _auth.RegisterAsync(request);
 if (result == null) return Conflict(new { message = "Email or username already taken." });
 return Ok(result);
 }

 [HttpPost("login")]
 public async Task<IActionResult> Login(LoginRequest request)
 {
 var result = await _auth.LoginAsync(request);
 if (result == null) return Unauthorized(new { message = "Invalid credentials." });
 return Ok(result);
 }
}

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class PostsController : ControllerBase
{
 private readonly IPostService _posts;
 public PostsController(IPostService posts) => _posts = posts;

 private int UserId => int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);

 [HttpGet("feed")]
 public async Task<IActionResult> Feed([FromQuery] int page = 1, [FromQuery] int pageSize = 20)
 => Ok(await _posts.GetFeedAsync(UserId, page, pageSize));

 [HttpPost]
 public async Task<IActionResult> Create(CreatePostRequest request)
 => Ok(await _posts.CreateAsync(UserId, request));

 [HttpPost("{postId}/like")]
 public async Task<IActionResult> Like(int postId)
 {
 var liked = await _posts.LikeAsync(UserId, postId);
 return Ok(new { liked });
 }

 [HttpDelete("{postId}")]
 public async Task<IActionResult> Delete(int postId)
 {
 var success = await _posts.DeleteAsync(UserId, postId);
 if (!success) return Forbid();
 return NoContent();
 }
}

[ApiController]
[Route("api/[controller]")]
public class UsersController : ControllerBase
{
 private readonly IUserService _users;
 private readonly IPostService _posts;
 public UsersController(IUserService users, IPostService posts)
 {
 _users = users;
 _posts = posts;
 }

 private int? CurrentUserId => User.Identity?.IsAuthenticated == true
 ? int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!)
 : null;

 [HttpGet("{username}")]
 public async Task<IActionResult> GetProfile(string username)
 {
 var user = await _users.GetByUsernameAsync(username, CurrentUserId);
 if (user == null) return NotFound();
 return Ok(user);
 }

 [HttpGet("{username}/posts")]
 public async Task<IActionResult> GetUserPosts(string username, [FromQuery] int page = 1, [FromQuery] int pageSize = 20)
 {
 var user = await _users.GetByUsernameAsync(username, CurrentUserId);
 if (user == null) return NotFound();
 return Ok(await _posts.GetUserPostsAsync(user.Id, CurrentUserId, page, pageSize));
 }

 [HttpPut("me")]
 [Authorize]
 public async Task<IActionResult> UpdateProfile(UpdateProfileRequest request)
 {
 var userId = int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
 var user = await _users.UpdateProfileAsync(userId, request);
 return Ok(user);
 }

 [HttpPost("{username}/follow")]
 [Authorize]
 public async Task<IActionResult> Follow(string username)
 {
 var target = await _users.GetByUsernameAsync(username, CurrentUserId);
 if (target == null) return NotFound();

 var followerId = int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
 var following = await _users.FollowAsync(followerId, target.Id);
 return Ok(new { following });
 }

 [HttpGet("search")]
 public async Task<IActionResult> Search([FromQuery] string q)
 => Ok(await _users.SearchAsync(q));
}
