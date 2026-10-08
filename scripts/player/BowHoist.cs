using Godot;

/// <summary>Contact-aware reach, shoulder lift, seating and release, after the gait layers.</summary>
[GlobalClass]
public partial class BowHoist : SkeletonModifier3D
{
	[Signal] public delegate void HoistedEventHandler();
	[Signal] public delegate void DrawnEventHandler();
	[Signal] public delegate void ArrowReleasedEventHandler();
	[Signal] public delegate void CollectionFinishedEventHandler();
	public bool Busy { get; private set; }
	public bool HasBow { get; private set; }
	public bool IsDrawn { get; private set; }
	public bool UsesLeftHand => _usingLeft;
	public float Progress => CurrentDuration > 0 ? _elapsed / CurrentDuration : 0;
	public float HandError { get; private set; }
	public float AimWeight { get; set; }
	public float RunWeight { get; set; }
	public bool HasArrowForAim { get; set; }
	public Vector3 ArrowLaunchPosition => _bow != null && IsInstanceValid(_bow) ? _bow.GlobalPosition : Vector3.Zero;
	private Skeleton3D _rig = null!;
	private Node3D? _bow;
	private Node3D? _nockedArrow;
	private BoneAttachment3D _back = null!;
	private int _upper, _fore, _hand, _chest;
	private readonly int[] _arms = new int[6];
	private readonly int[] _fingers = new int[24];
	private bool _usingLeft;
	private float GripSign => _usingLeft ? -1 : 1;
	private Vector3 _startHand;
	private Transform3D _found;
	private Transform3D _carry;
	private Transform3D _backLocal;
	private Transform3D _held;
	private float _elapsed, _duration;
	private float _drawDuration;
	private enum Gesture { Hoist, Draw, Shoot, Collect }
	private Gesture _gesture;
	private float CurrentDuration => _gesture switch
	{
		Gesture.Draw => _drawDuration,
		Gesture.Shoot => 0.54f,
		Gesture.Collect => 0.9f,
		_ => _duration
	};
	private bool _ready;
	private bool _gripped;
	private bool _gestureSignalSent;

	public override void _Ready()
	{
		_rig = GetSkeleton();
		if (_rig == null) return;
		int armIndex = 0;
		foreach (string side in new[] { "R", "L" })
			foreach (string part in new[] { "upper_arm", "forearm", "hand" })
				_arms[armIndex++] = _rig.FindBone($"DEF-{part}.{side}");
		SelectArm(false);
		_chest = _rig.FindBone("DEF-spine.003");
		if (_upper < 0 || _fore < 0 || _hand < 0 || _chest < 0)
		{
			GD.PushError("BowHoist: required elf arm/chest bones missing");
			return;
		}
		int index = 0;
		foreach (string side in new[] { "R", "L" })
		{
			foreach (string finger in new[] { "index", "middle", "ring", "pinky" })
				for (int joint = 1; joint <= 3; joint++)
					_fingers[index++] = _rig.FindBone($"DEF-f_{finger}.0{joint}.{side}");
		}
		foreach (int bone in _arms)
			if (bone < 0) return;
		_back = new BoneAttachment3D { Name = "BowBack", BoneName = "DEF-spine.003" };
		_rig.AddChild(_back);
		var arrowScene = GD.Load<PackedScene>("res://assets/props/arrow/arrow.glb");
		if (arrowScene != null)
		{
			_nockedArrow = arrowScene.Instantiate<Node3D>();
			_nockedArrow.Name = "NockedArrow";
			_nockedArrow.Scale = Vector3.One * 0.8f;
			_nockedArrow.Visible = false;
			_rig.AddChild(_nockedArrow);
		}
		_ready = true;
	}

	public void Configure(float duration, Vector3 backPosition, float backRoll)
	{
		_duration = Mathf.Max(duration, 0.1f);
		_carry = new Transform3D(new Basis(Vector3.Back, backRoll), backPosition);
		if (_ready) _backLocal = _rig.GetBoneGlobalRest(_chest).AffineInverse() * _carry;
	}

	public void ConfigureDrawing(float duration, Vector3 handPosition, float handRoll)
	{
		_drawDuration = Mathf.Max(duration, 0.1f);
		_held = new Transform3D(new Basis(Vector3.Back, handRoll), handPosition);
	}

	public bool Begin(Node3D bow)
	{
		if (!_ready || Busy || HasBow || !IsInstanceValid(bow)) return false;
		_bow = bow;
		SelectArm(false);
		_found = _rig.GlobalTransform.AffineInverse() * bow.GlobalTransform;
		_startHand = _rig.GetBoneGlobalPose(_hand).Origin;
		_gripped = false;
		_gesture = Gesture.Hoist;
		_elapsed = 0;
		Busy = true;
		return true;
	}

	// Called by Player's physics tick only while PLAYING. Menus/journal freeze the gesture.
	public void Advance(float delta)
	{
		if (Busy) _elapsed = Mathf.Min(_elapsed + delta, CurrentDuration);
	}

	public bool Draw()
	{
		if (!_ready || Busy || !HasBow || IsDrawn || _bow == null) return false;
		SelectArm(true);
		_startHand = _rig.GetBoneGlobalPose(_hand).Origin;
		_gripped = false;
		_gesture = Gesture.Draw;
		_elapsed = 0;
		Busy = true;
		return true;
	}

	public bool Stow()
	{
		if (!_ready || Busy || !HasBow || !IsDrawn || _bow == null) return false;
		SelectArm(true);
		_found = _rig.GlobalTransform.AffineInverse() * _bow.GlobalTransform;
		_startHand = _rig.GetBoneGlobalPose(_hand).Origin;
		_gripped = true;
		_gestureSignalSent = false;
		_gesture = Gesture.Hoist;
		_elapsed = 0;
		Busy = true;
		return true;
	}

	public bool Shoot()
	{
		if (!_ready || Busy || !HasBow || !IsDrawn || _bow == null) return false;
		SelectArm(false);
		_startHand = _rig.GetBoneGlobalPose(_hand).Origin;
		_gripped = true;
		_gesture = Gesture.Shoot;
		_elapsed = 0;
		_gestureSignalSent = false;
		Busy = true;
		return true;
	}

	public bool BeginCollection()
	{
		if (!_ready || Busy) return false;
		SelectArm(false);
		_startHand = _rig.GetBoneGlobalPose(_hand).Origin;
		_gesture = Gesture.Collect;
		_elapsed = 0;
		_gestureSignalSent = false;
		Busy = true;
		return true;
	}

	public void Restore(Node3D bow)
	{
		if (!_ready || Busy || HasBow) return;
		_bow = bow;
		AttachBack();
		HasBow = true;
	}

	public override void _ProcessModificationWithDelta(double delta)
	{
		if (_bow == null || !IsInstanceValid(_bow)) return;
		if (!Busy)
		{
			if (IsDrawn)
			{
				var readyPosition = _held.Origin + new Vector3(
					Mathf.Lerp(0.0f, -0.04f, RunWeight),
					Mathf.Lerp(-0.06f, -0.17f, RunWeight) + 0.12f * AimWeight,
					Mathf.Lerp(0.03f, 0.08f, AimWeight));
				HoldBow(readyPosition, _held.Basis.GetRotationQuaternion(), 1);
				UpdateNockedArrow(readyPosition);
				SelectArm(false);
				var support = new Vector3(
					Mathf.Lerp(-0.15f, -0.08f, AimWeight),
					Mathf.Lerp(1.4f, 1.5f, AimWeight) - 0.12f * RunWeight,
					Mathf.Lerp(0.1f, 0.2f, AimWeight));
				SolveArm(support, 1);
				CurlFingers(_rig.GetBoneGlobalPose(_hand).Basis.X.Normalized(), 0.35f + 0.55f * AimWeight);
				SelectArm(true);
			}
			return;
		}
		if (_gesture == Gesture.Shoot)
		{
			ShootPose(Progress);
			return;
		}
		if (_gesture == Gesture.Collect)
		{
			CollectPose(Progress);
			return;
		}
		float t = Mathf.Clamp(Progress, 0, 1);
		if (_gesture == Gesture.Draw)
		{
			DrawPose(t);
			return;
		}
		if (!_gripped)
			_found = _rig.GlobalTransform.AffineInverse() * _bow.GlobalTransform;
		// Lean slightly toward the found grip, then straighten under the lift.
		float lean = Ease(t / 0.16f) * (1 - Ease((t - 0.2f) / 0.3f));
		RotateGlobal(_chest, new Quaternion(Vector3.Right, 0.14f * lean));
		var carry = _rig.GetBoneGlobalPose(_chest) * _backLocal;
		Vector3 raised = new(-0.46f * GripSign, 1.78f, 0.32f);
		Vector3 over = new(-0.38f * GripSign, 2.02f, -0.08f);
		Quaternion from = _found.Basis.Orthonormalized().GetRotationQuaternion();
		Quaternion to = carry.Basis.Orthonormalized().GetRotationQuaternion();
		var rotation = from.Slerp(to, Ease((t - 0.43f) / 0.37f));
		var bowFrame = new Basis(rotation);
		// Wrist is behind the palm: grasp the handle, not with the wrist joint.
		var handFrame = new Basis(bowFrame.Y * GripSign, bowFrame.X * GripSign, -bowFrame.Z);
		Vector3 gripOffset = handFrame.Y * 0.085f;
		Vector3 target;
		if (t < 0.12f) target = _startHand.Lerp(_found.Origin - gripOffset, Ease(t / 0.12f));
		else if (t < 0.43f) target = _found.Origin.Lerp(raised, Ease((t - 0.12f) / 0.31f)) - gripOffset;
		else if (t < 0.6f) target = raised.Lerp(over, Ease((t - 0.43f) / 0.17f)) - gripOffset;
		else if (t < 0.8f) target = over.Lerp(carry.Origin, Ease((t - 0.6f) / 0.2f)) - gripOffset;
		else target = carry.Origin - gripOffset;
		float weight = 1 - Ease((t - 0.82f) / 0.18f);
		SolveArm(target, weight);
		var handPose = _rig.GetBoneGlobalPose(_hand);
		SetGlobalRotation(_hand, handPose.Basis.GetRotationQuaternion().Slerp(
			handFrame.GetRotationQuaternion(), Ease(t / 0.12f) * weight));
		float grip = Ease((t - 0.09f) / 0.04f) * (1 - Ease((t - 0.79f) / 0.08f));
		Vector3 curlAxis = _rig.GetBoneGlobalPose(_hand).Basis.X.Normalized();
		CurlFingers(curlAxis, grip);
		if (IsDrawn)
			PoseSupportArm(1 - Ease(t / 0.42f));

		if (t >= 0.12f && t < 0.8f)
		{
			if (!_gripped)
			{
				_bow.Reparent(_rig, true);
				_gripped = true;
			}
			// The grip follows the evaluated hand, including any reach clamping.
			Vector3 handAt = _rig.GetBoneGlobalPose(_hand).Origin + gripOffset;
			// Ease the final few centimetres onto the harness instead of snapping
			// when a walking shoulder makes the last reach slightly shorter.
			Vector3 seated = handAt.Lerp(carry.Origin, Ease((t - 0.74f) / 0.06f));
			_bow.Transform = new Transform3D(new Basis(rotation).Scaled(_found.Basis.Scale), seated);
		}
		else if (t >= 0.8f && _bow.GetParent() != _back)
		{
			AttachBack();
			HasBow = true;
			IsDrawn = false;
		}
		if (t >= 1)
		{
			Busy = false;
			EmitSignal(SignalName.Hoisted);
		}
	}

	private void DrawPose(float t)
	{
		// Until the grip closes, the bow stays on the moving back attachment.
		if (!_gripped) _found = _rig.GlobalTransform.AffineInverse() * _bow!.GlobalTransform;
		Vector3 over = new(0.38f, 2.02f, -0.08f);
		Vector3 raised = new(0.46f, 1.78f, 0.32f);
		Quaternion rotation = _found.Basis.Orthonormalized().GetRotationQuaternion().Slerp(
			_held.Basis.GetRotationQuaternion(), Ease((t - 0.23f) / 0.67f));
		Vector3 target;
		if (t < 0.23f)
		{
			var frame = new Basis(rotation);
			target = _startHand.Lerp(_found.Origin - frame.X * GripSign * 0.085f, Ease(t / 0.23f));
			SolveArm(target, 1);
			PoseGrip(rotation, Ease(t / 0.23f), Ease((t - 0.18f) / 0.05f));
			PoseSupportArm(0);
			return;
		}
		if (!_gripped)
		{
			_bow!.Reparent(_rig, true);
			_gripped = true;
		}
		if (t < 0.48f) target = _found.Origin.Lerp(over, Ease((t - 0.23f) / 0.25f));
		else if (t < 0.7f) target = over.Lerp(raised, Ease((t - 0.48f) / 0.22f));
		else target = raised.Lerp(_held.Origin, Ease((t - 0.7f) / 0.3f));
		HoldBow(target, rotation, 1);
		PoseSupportArm(Ease((t - 0.43f) / 0.52f));
		if (t >= 1)
		{
			IsDrawn = true;
			Busy = false;
			EmitSignal(SignalName.Drawn);
		}
	}

	private void ShootPose(float t)
	{
		SelectArm(true);
		var readyPosition = _held.Origin + new Vector3(0.0f, 0.12f, 0.08f);
		HoldBow(readyPosition, _held.Basis.GetRotationQuaternion(), 1);
		SelectArm(false);
		float draw = Ease(t / 0.42f);
		Vector3 target = new(
			Mathf.Lerp(-0.15f, -0.12f, draw),
			Mathf.Lerp(1.42f, 1.5f, draw),
			Mathf.Lerp(0.12f, 0.28f, draw));
		if (t > 0.72f)
			target.Z = Mathf.Lerp(0.28f, 0.14f, Ease((t - 0.72f) / 0.28f));
		SolveArm(target, 1);
		CurlFingers(_rig.GetBoneGlobalPose(_hand).Basis.X.Normalized(), t < 0.78f ? 1 : 0);
		if (!_gestureSignalSent && t >= 0.58f)
		{
			_gestureSignalSent = true;
			if (_nockedArrow != null) _nockedArrow.Visible = false;
			EmitSignal(SignalName.ArrowReleased);
		}
		if (t >= 1)
		{
			Busy = false;
			SelectArm(true);
		}
	}

	private void UpdateNockedArrow(Vector3 position)
	{
		if (_nockedArrow == null) return;
		_nockedArrow.Visible = HasArrowForAim && AimWeight > 0.18f;
		if (!_nockedArrow.Visible) return;
		var basis = _rig.GlobalBasis * _held.Basis * new Basis(Vector3.Right, -Mathf.Pi * 0.5f);
		var localPosition = position + new Vector3(0.0f, 0.01f, 0.035f);
		_nockedArrow.GlobalTransform = new Transform3D(basis, _rig.GlobalTransform * localPosition);
	}

	private void PoseSupportArm(float weight)
	{
		SelectArm(false);
		Vector3 support = new(
			Mathf.Lerp(-0.15f, -0.08f, AimWeight),
			Mathf.Lerp(1.4f, 1.5f, AimWeight),
			Mathf.Lerp(0.1f, 0.2f, AimWeight));
		Vector3 natural = _rig.GetBoneGlobalPose(_hand).Origin;
		SolveArm(natural.Lerp(support, weight), 1);
		CurlFingers(_rig.GetBoneGlobalPose(_hand).Basis.X.Normalized(), weight * 0.85f);
		SelectArm(true);
	}

	private void CollectPose(float t)
	{
		if (IsDrawn)
		{
			SelectArm(true);
			HoldBow(_held.Origin, _held.Basis.GetRotationQuaternion(), 1);
			SelectArm(false);
		}
		Vector3 reach = new(-0.05f, 1.14f, 0.0f);
		Vector3 stow = new(-0.15f, 1.42f, -0.1f);
		Vector3 target = t < 0.62f
			? new Vector3(-0.15f, 1.4f, 0.08f).Lerp(reach, Ease(t / 0.62f))
			: reach.Lerp(stow, Ease((t - 0.62f) / 0.38f));
		SolveArm(target, 1);
		CurlFingers(_rig.GetBoneGlobalPose(_hand).Basis.X.Normalized(), t > 0.54f ? 0.85f : 0.1f);
		if (t >= 1)
		{
			Busy = false;
			if (IsDrawn)
				SelectArm(true);
			EmitSignal(SignalName.CollectionFinished);
		}
	}

	private void HoldBow(Vector3 grip, Quaternion rotation, float weight)
	{
		var frame = new Basis(rotation);
		Vector3 offset = frame.X * GripSign * 0.085f;
		SolveArm(grip - offset, weight);
		PoseGrip(rotation, weight, weight);
		Vector3 palm = _rig.GetBoneGlobalPose(_hand).Origin + offset;
		_bow!.Transform = new Transform3D(frame, palm);
	}

	private void PoseGrip(Quaternion rotation, float weight, float grip)
	{
		var frame = new Basis(rotation);
		var handFrame = new Basis(frame.Y * GripSign, frame.X * GripSign, -frame.Z);
		SetGlobalRotation(_hand, _rig.GetBoneGlobalPose(_hand).Basis.GetRotationQuaternion().Slerp(
			handFrame.GetRotationQuaternion(), weight));
		Vector3 curlAxis = _rig.GetBoneGlobalPose(_hand).Basis.X.Normalized();
		CurlFingers(curlAxis, grip);
	}

	private void SelectArm(bool left)
	{
		_usingLeft = left;
		int first = left ? 3 : 0;
		_upper = _arms[first];
		_fore = _arms[first + 1];
		_hand = _arms[first + 2];
	}

	private void CurlFingers(Vector3 axis, float grip)
	{
		int first = _usingLeft ? 12 : 0;
		for (int index = first; index < first + 12; index++)
			if (_fingers[index] >= 0)
				RotateGlobal(_fingers[index], new Quaternion(axis, 0.85f * grip));
	}

	private void AttachBack()
	{
		if (_bow == null) return;
		// Carry is in skeleton metres; the parent rig already owns model scale.
		var bone = _rig.GetBoneGlobalPose(_chest);
		_back.Transform = bone;
		_bow.Reparent(_back, false);
		_bow.Transform = _backLocal;
	}

	private void SolveArm(Vector3 target, float weight)
	{
		var upper = _rig.GetBoneGlobalPose(_upper);
		var fore = _rig.GetBoneGlobalPose(_fore);
		var hand = _rig.GetBoneGlobalPose(_hand);
		Vector3 shoulder = upper.Origin;
		float a = shoulder.DistanceTo(fore.Origin);
		float b = fore.Origin.DistanceTo(hand.Origin);
		Vector3 toward = target - shoulder;
		float distance = Mathf.Clamp(toward.Length(), Mathf.Abs(a - b) + 0.005f, a + b - 0.005f);
		Vector3 direction = toward.Normalized();
		// Keep the active elbow outside its shoulder, away from the torso.
		Vector3 pole = new Vector3(-GripSign, 0.1f, 0.15f);
		Vector3 perpendicular = (pole - direction * pole.Dot(direction)).Normalized();
		float along = (a * a - b * b + distance * distance) / (2 * distance);
		float height = Mathf.Sqrt(Mathf.Max(a * a - along * along, 0));
		Vector3 elbow = shoulder + direction * along + perpendicular * height;
		Vector3 end = shoulder + direction * distance;
		Quaternion turn = new Quaternion((fore.Origin - shoulder).Normalized(), (elbow - shoulder).Normalized());
		SetGlobalRotation(_upper, upper.Basis.GetRotationQuaternion().Slerp(
			turn * upper.Basis.GetRotationQuaternion(), weight));
		// Parent changed: read the evaluated forearm once before solving its rotation.
		fore = _rig.GetBoneGlobalPose(_fore);
		hand = _rig.GetBoneGlobalPose(_hand);
		turn = new Quaternion((hand.Origin - fore.Origin).Normalized(), (end - fore.Origin).Normalized());
		SetGlobalRotation(_fore, fore.Basis.GetRotationQuaternion().Slerp(
			turn * fore.Basis.GetRotationQuaternion(), weight));
		HandError = _rig.GetBoneGlobalPose(_hand).Origin.DistanceTo(target);
	}

	private void RotateGlobal(int bone, Quaternion rotation)
	{
		SetGlobalRotation(bone, rotation * _rig.GetBoneGlobalPose(bone).Basis.GetRotationQuaternion());
	}

	private void SetGlobalRotation(int bone, Quaternion rotation)
	{
		var pose = _rig.GetBoneGlobalPose(bone);
		pose.Basis = new Basis(rotation.Normalized()).Scaled(pose.Basis.Scale);
		_rig.SetBoneGlobalPose(bone, pose);
	}

	private static float Ease(float value) => Mathf.SmoothStep(0, 1, Mathf.Clamp(value, 0, 1));
}
