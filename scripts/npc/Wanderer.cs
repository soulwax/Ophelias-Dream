using System;
using System.Collections.Generic;
using Godot;
using Godot.Collections;

/// <summary>
/// The one not being played, walking her own afternoon along a path, and the rare
/// moments she and the player pass each other (docs/MATHILDA_STORY.md, "When they
/// pass each other"). Movement, perception and the passing's body language live
/// here; what is said is staged by Encounters (GDScript), which listens to the signals.
/// </summary>
[GlobalClass]
public partial class Wanderer : Node3D
{
	[Signal] public delegate void PassingBeganEventHandler(int number);
	[Signal] public delegate void PassingEndedEventHandler(int number, Vector3 spot, bool broken);
	[Signal] public delegate void SteppedEventHandler(Vector3 at);

	private enum Mode { Offstage, Linger, Walk, Hesitate, Notice, Passing, Leave, Retired }

	private struct Haunt
	{
		public float S;
		public float Side;
		public string Act;
		public Vector3 Look;
	}

	/// <summary>Set every frame by Encounters: may she be out there at all.</summary>
	public bool Allowed { get; set; }

	/// <summary>Prefer appearing ahead of the player along the path (Ophelia walks forward).</summary>
	public bool AheadBias { get; set; }

	public string State => _mode.ToString();
	public int Passings => _passings;
	public bool Present => _mode != Mode.Offstage && _mode != Mode.Retired;

	private const uint WorldLayer = 1;

	private Node _game = null!;
	private int _phasePlaying;
	private Node3D? _body;
	private AnimationPlayer? _anim;
	private readonly List<CollisionObject3D> _colliders = new();
	private readonly List<uint> _colliderLayers = new();
	private Godot.Collections.Array<Rid> _exclude = new();

	private Vector3[] _points = System.Array.Empty<Vector3>();
	private float[] _cum = System.Array.Empty<float>();
	private float _length;
	private readonly List<Haunt> _haunts = new();

	private readonly RandomNumberGenerator _rng = new();
	private Mode _mode = Mode.Offstage;
	private Mode _resumeMode = Mode.Walk;
	private float _s;
	private float _side;
	private float _fromSide;
	private float _fromS;
	private float _targetS;
	private float _targetSide;
	private float _speed = 1.0f;
	private float _timer;
	private float _stayLeft;
	private float _stepAcc;
	private float _yaw;
	private float _yawGoal;
	private float _gazeOffset;
	private float _gazeTimer;
	private float _swayClock;
	private int _hauntIndex = -1;
	private string _act = "gaze";
	private Vector3 _look;
	private int _passings;
	private bool _hesitated;
	private bool _glanced;
	private bool _retiring;
	private bool _crouching;
	// After a passing she has to go offstage before another can happen.
	private bool _mayPass = true;
	private float _crouchLeft;
	private float _awayLeft;
	private float _awayYaw;
	private Vector3 _spot;
	private string _playing = "";

	// Tune.PASS_*, read once from the GDScript constants so balance stays in Tune.
	private Vector2 _first, _every, _after, _stay, _enter, _walk;
	private float _chance, _range, _break, _stepLength, _personal, _strideWalk;
	private int _max;

	public override void _Ready()
	{
		PhysicsInterpolationMode = PhysicsInterpolationModeEnum.Off;
		_rng.Randomize();
		_game = GetNode("/root/Game");
		var gameConstants = ((Script)_game.GetScript()).GetScriptConstantMap();
		_phasePlaying = ((Dictionary)gameConstants["Phase"])["PLAYING"].AsInt32();
		var tune = GD.Load<Script>("res://scripts/tune.gd").GetScriptConstantMap();
		_first = tune["PASS_FIRST"].AsVector2();
		_every = tune["PASS_EVERY"].AsVector2();
		_after = tune["PASS_AFTER"].AsVector2();
		_stay = tune["PASS_STAY"].AsVector2();
		_enter = tune["PASS_ENTER"].AsVector2();
		_walk = tune["PASS_WALK"].AsVector2();
		_chance = tune["PASS_CHANCE"].AsSingle();
		_range = tune["PASS_RANGE"].AsSingle();
		_break = tune["PASS_BREAK"].AsSingle();
		_stepLength = tune["PASS_STEP"].AsSingle();
		_personal = tune["PASS_PERSONAL"].AsSingle();
		_max = tune["PASS_MAX"].AsInt32();
		_strideWalk = tune["STRIDE_WALK"].AsSingle();
		Visible = false;
	}

	/// <summary>
	/// The body (an OpheliaNpc, already a child), the path she walks (outdoor, clear of
	/// trees), the places she stops ({at: Vector3, act: String, look: Vector3}) and how
	/// long before she can first appear.
	/// </summary>
	public void Setup(Node3D body, Vector3[] path, Godot.Collections.Array<Dictionary> haunts, Vector2 firstDelay)
	{
		_body = body;
		_anim = body.Get("animation_player").AsGodotObject() as AnimationPlayer;
		foreach (var node in body.FindChildren("*", "CollisionObject3D", true, false))
		{
			if (node is CollisionObject3D collider)
			{
				_colliders.Add(collider);
				_colliderLayers.Add(collider.CollisionLayer);
				_exclude.Add(collider.GetRid());
			}
		}
		_points = path;
		_cum = new float[path.Length];
		for (int i = 1; i < path.Length; i++)
			_cum[i] = _cum[i - 1] + Flat(path[i] - path[i - 1]).Length();
		_length = path.Length > 0 ? _cum[^1] : 0f;
		_haunts.Clear();
		foreach (var item in haunts)
		{
			var at = item["at"].AsVector3();
			float s = Project(at);
			var flat = Flat(at - Sample(s));
			float side = flat.Dot(Lateral(s));
			_haunts.Add(new Haunt
			{
				S = s,
				Side = side,
				Act = item.ContainsKey("act") ? item["act"].AsString() : "gaze",
				Look = item.ContainsKey("look") ? item["look"].AsVector3() : at + Vector3.Forward,
			});
		}
		_first = firstDelay;
		GoOffstage(firstDelay);
	}

	/// <summary>Encounters ends the passing: she turns and walks away, looking back once.</summary>
	public void Leave() => BeginLeave(false);

	/// <summary>She stops coming out (the meeting is set, or she was turned away from).</summary>
	public void Retire()
	{
		_retiring = true;
		if (_mode == Mode.Offstage)
			Disappear(Mode.Retired);
		else if (_mode == Mode.Passing || _mode == Mode.Notice)
			BeginLeave(true);
	}

	/// <summary>She looks away for a moment and back.</summary>
	public void LookAway(float seconds)
	{
		_awayLeft = seconds;
		_awayYaw = (_rng.Randf() < 0.5f ? -1f : 1f) * _rng.RandfRange(0.8f, 1.25f);
	}

	/// <summary>She crouches, as if her boot needed it, and stands again.</summary>
	public void Crouch(float seconds)
	{
		_crouchLeft = seconds;
		Play("Crouch_Idle", 0.5f);
		_crouching = true;
	}

	/// <summary>Dev hook and probe: bring her out at the haunt nearest a point now.</summary>
	public void ForceEnterNear(Vector3 at)
	{
		if (_haunts.Count == 0 || _mode == Mode.Retired)
			return;
		int best = 0;
		float bestDistance = float.MaxValue;
		for (int i = 0; i < _haunts.Count; i++)
		{
			float d = Flat(HauntPosition(i) - at).Length();
			if (d < bestDistance)
			{
				bestDistance = d;
				best = i;
			}
		}
		Enter(best);
	}

	public Vector3 Head() => _body != null ? _body.Call("head").AsVector3() : GlobalPosition + Vector3.Up * 1.45f;

	public override void _Process(double deltaTime)
	{
		float delta = (float)deltaTime;
		if (_mode == Mode.Retired || _body == null || _points.Length < 2)
			return;
		var player = _game.Get("player").AsGodotObject() as Node3D;
		if (player == null)
			return;
		bool playing = _game.Get("phase").AsInt32() == _phasePlaying;
		var you = player.GlobalPosition;
		float apart = Flat(you - GlobalPosition).Length();

		switch (_mode)
		{
			case Mode.Offstage:
				if (!Allowed || !playing)
					return;
				_timer -= delta;
				if (_timer > 0f)
					return;
				if (_retiring)
				{
					Disappear(Mode.Retired);
					return;
				}
				if (_rng.Randf() < _chance && TryEnter(you))
					return;
				_timer = _rng.RandfRange(15f, 30f);
				return;

			case Mode.Linger:
				Linger(delta);
				if (CheckPassing(playing, you, apart))
					break;
				MaybeGoOffstage(delta, apart);
				break;

			case Mode.Walk:
				Walk(delta, Mode.Linger);
				if (CheckPassing(playing, you, apart))
					break;
				MaybeGoOffstage(delta, apart);
				break;

			case Mode.Hesitate:
				_timer -= delta;
				_yawGoal = YawAlong() + _gazeOffset;
				if (_timer <= 0f)
				{
					_mode = _resumeMode;
					Play("Walk_Formal", 0.4f);
				}
				if (CheckPassing(playing, you, apart))
					break;
				break;

			case Mode.Notice:
				// She has seen her, and has not decided what her face should do yet.
				_timer -= delta;
				if (_timer < 1.0f)
					_yawGoal = YawTo(you);
				if (_timer <= 0f)
				{
					_mode = Mode.Passing;
					_timer = 45f;
					_gazeTimer = _rng.RandfRange(2.5f, 4.5f);
					EmitSignal(SignalName.PassingBegan, _passings);
				}
				if (apart > _break)
					BeginLeave(true);
				break;

			case Mode.Passing:
				Passing(delta, you, apart, playing);
				break;

			case Mode.Leave:
				Walk(delta, Mode.Leave);
				if (!_glanced && apart > 6.5f && apart < 22f)
				{
					// Once, over her shoulder.
					_glanced = true;
					_mode = Mode.Hesitate;
					_resumeMode = Mode.Leave;
					_timer = _rng.RandfRange(1.0f, 1.6f);
					_gazeOffset = WrapAngle(YawTo(you) - YawAlong());
					Play("Idle", 0.35f);
					break;
				}
				if ((apart > 28f && !Seen()) || (ArrivedAt(_targetS) && !Seen() && apart > 14f))
				{
					Disappear(_retiring ? Mode.Retired : Mode.Offstage);
					_timer = _rng.RandfRange(_after.X, _after.Y);
				}
				else if (ArrivedAt(_targetS))
				{
					SetWalkTarget(FarEnd(you), _side, _rng.RandfRange(_walk.X, _walk.Y));
				}
				break;
		}
		Place(delta);
	}

	// ---------------------------------------------------------------- behaviours

	private void Linger(float delta)
	{
		_timer -= delta;
		_swayClock += delta;
		if (_crouching)
		{
			_crouchLeft -= delta;
			if (_crouchLeft <= 0f)
			{
				_crouching = false;
				Play("Idle", 0.6f);
			}
		}
		switch (_act)
		{
			case "crouch":
			case "warm":
				_yawGoal = YawTo(_look);
				if (!_crouching && _playing != "Crouch_Idle")
					Play("Crouch_Idle", 0.6f);
				break;
			case "still":
				_yawGoal = YawTo(_look);
				break;
			default:
				// Weight shifts and small looks: she is thinking about something.
				_gazeTimer -= delta;
				if (_gazeTimer <= 0f)
				{
					_gazeTimer = _rng.RandfRange(2.5f, 7f);
					_gazeOffset = _rng.Randf() < 0.35f ? _rng.RandfRange(-1.1f, 1.1f) : 0f;
				}
				_yawGoal = YawTo(_look) + _gazeOffset + Mathf.Sin(_swayClock * 0.37f) * 0.08f;
				break;
		}
		if (_timer <= 0f)
		{
			if (_playing == "Crouch_Idle")
				Play("Idle", 0.6f);
			_crouching = false;
			int next = NextHaunt();
			_hauntIndex = next;
			SetWalkTarget(_haunts[next].S, _haunts[next].Side, _rng.RandfRange(_walk.X, _walk.Y));
			_mode = Mode.Walk;
		}
	}

	private void Walk(float delta, Mode arriveAs)
	{
		float dir = Mathf.Sign(_targetS - _s);
		float step = _speed * delta;
		if (Mathf.Abs(_targetS - _s) <= step)
		{
			_s = _targetS;
			_side = _targetSide;
			if (arriveAs == Mode.Linger)
				Arrive();
			return;
		}
		_s += dir * step;
		float total = Mathf.Max(Mathf.Abs(_targetS - _fromS), 0.01f);
		float done = Mathf.Clamp(Mathf.Abs(_s - _fromS) / total, 0f, 1f);
		_side = Mathf.Lerp(_fromSide, _targetSide, Mathf.SmoothStep(0f, 1f, done));
		_yawGoal = YawAlong();
		_stepAcc += step;
		if (_stepAcc >= _stepLength)
		{
			_stepAcc -= _stepLength;
			EmitSignal(SignalName.Stepped, GlobalPosition);
		}
		// Now and then she stops halfway, looks aside, and goes on.
		if (arriveAs == Mode.Linger && !_hesitated && done > 0.35f && done < 0.6f && total > 12f)
		{
			_hesitated = true;
			if (_rng.Randf() < 0.3f)
			{
				_mode = Mode.Hesitate;
				_resumeMode = Mode.Walk;
				_timer = _rng.RandfRange(1.4f, 3.2f);
				_gazeOffset = _rng.RandfRange(0.7f, 1.4f) * (_rng.Randf() < 0.5f ? -1f : 1f);
				Play("Idle", 0.4f);
			}
		}
	}

	private void Arrive()
	{
		var haunt = _haunts[_hauntIndex];
		_act = haunt.Act;
		_look = haunt.Look;
		_mode = Mode.Linger;
		_timer = _rng.RandfRange(8f, 22f);
		_gazeTimer = _rng.RandfRange(1.5f, 4f);
		_gazeOffset = 0f;
		Play(_act == "crouch" || _act == "warm" ? "Crouch_Idle" : "Idle", 0.5f);
	}

	private void Passing(float delta, Vector3 you, float apart, bool playing)
	{
		_timer -= delta;
		if (_crouching)
		{
			_crouchLeft -= delta;
			if (_crouchLeft <= 0f)
			{
				_crouching = false;
				Play("Idle", 0.6f);
			}
		}
		// She cannot hold the look: it slides off and comes back.
		float look = YawTo(you);
		if (_awayLeft > 0f)
		{
			_awayLeft -= delta;
			look += _awayYaw;
		}
		else
		{
			_gazeTimer -= delta;
			if (_gazeTimer <= 0f)
			{
				_gazeTimer = _rng.RandfRange(2.8f, 5f);
				LookAway(_rng.RandfRange(0.9f, 1.7f));
			}
		}
		_yawGoal = look;
		// Too close: half a step back, not away.
		if (apart < _personal)
		{
			var back = Flat(GlobalPosition - you).Normalized();
			var tangent = Tangent(_s);
			_s = Mathf.Clamp(_s + back.Dot(tangent) * delta * 0.8f, 0f, _length);
			_side = Mathf.Clamp(_side + back.Dot(Lateral(_s)) * delta * 0.8f, -6f, 6f);
		}
		if (apart > _break || !Allowed || _timer <= 0f)
			BeginLeave(true);
	}

	// ---------------------------------------------------------------- decisions

	private bool CheckPassing(bool playing, Vector3 you, float apart)
	{
		if (!_mayPass || !playing || !Allowed || _retiring || _passings >= _max || apart > _range)
			return false;
		if (!LineOfSight(you + Vector3.Up * 1.5f, Head()))
			return false;
		_passings++;
		_mayPass = false;
		_mode = Mode.Notice;
		_timer = _rng.RandfRange(1.6f, 2.4f);
		_spot = GlobalPosition;
		_crouching = false;
		Play("Idle", 0.3f);
		return true;
	}

	private void BeginLeave(bool broken)
	{
		if (_mode != Mode.Passing && _mode != Mode.Notice)
			return;
		var player = _game.Get("player").AsGodotObject() as Node3D;
		var you = player?.GlobalPosition ?? GlobalPosition;
		_glanced = false;
		_crouching = false;
		_awayLeft = 0f;
		SetWalkTarget(FarEnd(you), _side, _rng.RandfRange(_walk.X + 0.1f, _walk.Y + 0.15f));
		_mode = Mode.Leave;
		EmitSignal(SignalName.PassingEnded, _passings, _spot, broken);
	}

	private void MaybeGoOffstage(float delta, float apart)
	{
		_stayLeft -= delta;
		if (Allowed && _stayLeft > 0f && !_retiring)
			return;
		if (Seen() && apart < 60f)
			return;
		Disappear(_retiring ? Mode.Retired : Mode.Offstage);
		_timer = _rng.RandfRange(_every.X, _every.Y);
	}

	private bool TryEnter(Vector3 you)
	{
		float youS = Project(you);
		var candidates = new List<int>();
		var ahead = new List<int>();
		for (int i = 0; i < _haunts.Count; i++)
		{
			var at = HauntPosition(i);
			float d = Flat(at - you).Length();
			if (d < _enter.X || d > _enter.Y || SeenAt(at + Vector3.Up * 1.4f))
				continue;
			candidates.Add(i);
			if (_haunts[i].S > youS)
				ahead.Add(i);
		}
		var pool = AheadBias && ahead.Count > 0 && _rng.Randf() < 0.75f ? ahead : candidates;
		if (pool.Count == 0)
			return false;
		Enter(pool[_rng.RandiRange(0, pool.Count - 1)]);
		return true;
	}

	private void Enter(int index)
	{
		_hauntIndex = index;
		_mayPass = true;
		_s = _haunts[index].S;
		_side = _haunts[index].Side;
		_targetS = _s;
		_targetSide = _side;
		_stayLeft = _rng.RandfRange(_stay.X, _stay.Y);
		Visible = true;
		for (int i = 0; i < _colliders.Count; i++)
			_colliders[i].CollisionLayer = _colliderLayers[i];
		Arrive();
		_yaw = YawTo(_look);
		_yawGoal = _yaw;
		Place(0f, true);
		ResetPhysicsInterpolation();
	}

	private void Disappear(Mode next)
	{
		_mode = next;
		_mayPass = true;
		Visible = false;
		_crouching = false;
		for (int i = 0; i < _colliders.Count; i++)
			_colliders[i].CollisionLayer = 0;
	}

	private void GoOffstage(Vector2 delay)
	{
		Disappear(Mode.Offstage);
		_timer = _rng.RandfRange(delay.X, delay.Y);
	}

	private int NextHaunt()
	{
		var near = new List<int>();
		for (int i = 0; i < _haunts.Count; i++)
		{
			if (i != _hauntIndex && Mathf.Abs(_haunts[i].S - _s) < 65f)
				near.Add(i);
		}
		if (near.Count == 0)
			return Mathf.Clamp(_hauntIndex + (_rng.Randf() < 0.5f ? -1 : 1), 0, _haunts.Count - 1);
		_hesitated = false;
		return near[_rng.RandiRange(0, near.Count - 1)];
	}

	private void SetWalkTarget(float s, float side, float speed)
	{
		_fromS = _s;
		_fromSide = _side;
		_targetS = Mathf.Clamp(s, 0f, _length);
		_targetSide = side;
		_speed = speed;
		_hesitated = false;
		Play("Walk_Formal", 0.4f);
	}

	private float FarEnd(Vector3 you)
	{
		float youS = Project(you);
		float away = _s >= youS ? 1f : -1f;
		return Mathf.Clamp(_s + away * _rng.RandfRange(40f, 70f), 0f, _length);
	}

	private bool ArrivedAt(float s) => Mathf.Abs(_s - s) < 0.05f;

	// ---------------------------------------------------------------- perception

	private bool Seen() => Visible && SeenAt(Head());

	private bool SeenAt(Vector3 point)
	{
		var camera = GetViewport()?.GetCamera3D();
		if (camera == null)
			return false;
		if (camera.IsPositionBehind(point) || !camera.IsPositionInFrustum(point))
			return false;
		if (camera.GlobalPosition.DistanceTo(point) > 120f)
			return false;
		return LineOfSight(camera.GlobalPosition, point);
	}

	private bool LineOfSight(Vector3 from, Vector3 to)
	{
		var space = GetWorld3D().DirectSpaceState;
		var query = PhysicsRayQueryParameters3D.Create(from, to, WorldLayer, _exclude);
		return space.IntersectRay(query).Count == 0;
	}

	// ---------------------------------------------------------------- the body

	private void Place(float delta, bool snap = false)
	{
		var flat = Sample(_s) + Lateral(_s) * _side;
		var from = new Vector3(flat.X, flat.Y + 2.5f, flat.Z);
		var to = new Vector3(flat.X, flat.Y - 6f, flat.Z);
		var hit = GetWorld3D().DirectSpaceState.IntersectRay(PhysicsRayQueryParameters3D.Create(from, to, WorldLayer, _exclude));
		var at = hit.Count > 0 ? hit["position"].AsVector3() : flat;
		GlobalPosition = at;
		float rate = _mode == Mode.Walk || _mode == Mode.Leave ? 5f : 2.2f;
		_yaw = snap ? _yawGoal : Mathf.LerpAngle(_yaw, _yawGoal, 1f - Mathf.Exp(-delta * rate));
		Rotation = new Vector3(0f, _yaw, 0f);
		if (_anim != null && _playing == "Walk_Formal")
			_anim.SpeedScale = _speed / Mathf.Max(_strideWalk, 0.1f);
		else if (_anim != null)
			_anim.SpeedScale = 1f;
	}

	private void Play(string clip, float blend)
	{
		if (_anim == null || !_anim.HasAnimation(clip) || _playing == clip)
			return;
		_playing = clip;
		_anim.Play(clip, blend);
	}

	// ---------------------------------------------------------------- the path

	private Vector3 HauntPosition(int i) => Sample(_haunts[i].S) + Lateral(_haunts[i].S) * _haunts[i].Side;

	private Vector3 Sample(float s)
	{
		s = Mathf.Clamp(s, 0f, _length);
		int i = Segment(s);
		float span = Mathf.Max(_cum[i + 1] - _cum[i], 0.001f);
		return _points[i].Lerp(_points[i + 1], (s - _cum[i]) / span);
	}

	private Vector3 Tangent(float s)
	{
		int i = Segment(Mathf.Clamp(s, 0f, _length));
		var t = Flat(_points[i + 1] - _points[i]);
		return t.LengthSquared() > 0.0001f ? t.Normalized() : Vector3.Forward;
	}

	private Vector3 Lateral(float s) => Tangent(s).Cross(Vector3.Up).Normalized();

	private int Segment(float s)
	{
		int lo = 0, hi = _cum.Length - 2;
		while (lo < hi)
		{
			int mid = (lo + hi + 1) / 2;
			if (_cum[mid] <= s)
				lo = mid;
			else
				hi = mid - 1;
		}
		return Math.Max(0, lo);
	}

	private float Project(Vector3 at)
	{
		float best = 0f;
		float bestDistance = float.MaxValue;
		var flatAt = Flat(at);
		for (int i = 0; i + 1 < _points.Length; i++)
		{
			var a = Flat(_points[i]);
			var b = Flat(_points[i + 1]);
			var ab = b - a;
			float t = ab.LengthSquared() > 0.0001f ? Mathf.Clamp((flatAt - a).Dot(ab) / ab.LengthSquared(), 0f, 1f) : 0f;
			float d = (a + ab * t).DistanceSquaredTo(flatAt);
			if (d < bestDistance)
			{
				bestDistance = d;
				best = _cum[i] + (_cum[i + 1] - _cum[i]) * t;
			}
		}
		return best;
	}

	private float YawAlong()
	{
		var t = Tangent(_s) * Mathf.Sign(_targetS - _s == 0f ? 1f : _targetS - _s);
		return Mathf.Atan2(-t.X, -t.Z);
	}

	private float YawTo(Vector3 point)
	{
		var to = Flat(point - GlobalPosition);
		return to.LengthSquared() < 0.01f ? _yaw : Mathf.Atan2(-to.X, -to.Z);
	}

	private static float WrapAngle(float a) => Mathf.Wrap(a, -Mathf.Pi, Mathf.Pi);

	private static Vector3 Flat(Vector3 v) => new(v.X, 0f, v.Z);
}
