using Godot;

/// <summary>
/// Contact-aware modifier for photorealistic lantern pickup, front-wear chest harness socket,
/// hip stowage, and physics-driven pendulum sway during movement.
/// </summary>
[GlobalClass]
public partial class LanternHold : SkeletonModifier3D
{
	[Signal] public delegate void HoistedEventHandler();
	[Signal] public delegate void ToggledEventHandler(bool equipped);

	public bool Busy { get; private set; }
	public bool HasLantern { get; private set; }
	public bool IsEquipped { get; private set; }
	public float Progress => _duration > 0.001f ? Mathf.Clamp(_elapsed / _duration, 0.0f, 1.0f) : 1.0f;

	private Skeleton3D? _rig;
	private Node3D? _lantern;
	private Vector3 _scale = Vector3.One;

	// Bones
	private int _spine = -1;
	private int _spine1 = -1;
	private int _spine3 = -1;
	private int _spine4 = -1;
	private int _head = -1;

	private int _shoulderR = -1;
	private int _upperR = -1;
	private int _foreR = -1;
	private int _handR = -1;

	private readonly int[] _fingers = new int[12];
	private readonly Quaternion[] _restFingers = new Quaternion[12];
	private Quaternion _restUpperR = Quaternion.Identity;
	private Quaternion _restForeR = Quaternion.Identity;
	private Quaternion _restHandR = Quaternion.Identity;

	private Transform3D _found = Transform3D.Identity;
	private Vector3 _startHand = Vector3.Zero;
	private float _duration = 1.2f;
	private float _toggleSeconds = 0.55f;
	private float _elapsed;

	private enum Gesture { None, Pickup, Equip, Stow }
	private Gesture _gesture = Gesture.None;
	private bool _gripped;
	private bool _ready;

	// Dynamic pendulum sway while worn in front.
	private Vector2 _swayAngle = Vector2.Zero;
	private Vector2 _swayVelocity = Vector2.Zero;
	private Vector3 _lastWorldPos = Vector3.Zero;
	private Vector3 _lastVelocity = Vector3.Zero;

	// Offsets relative to bone origins (spine3 for chest, spine for hip).
	// In skeleton local space: forward is +Z, up is +Y, right is -X.
	private Vector3 _chestOffset = new(0.0f, -0.25f, 0.22f);
	private Vector3 _hipOffset = new(-0.20f, -0.10f, 0.12f);

	public override void _Ready()
	{
		_rig = GetSkeleton();
		if (_rig == null) return;

		// Bone lookups.
		_spine = _rig.FindBone("DEF-spine");
		_spine1 = _rig.FindBone("DEF-spine.001");
		_spine3 = _rig.FindBone("DEF-spine.003");
		_spine4 = _rig.FindBone("DEF-spine.004");
		_head = _rig.FindBone("DEF-spine.006");

		_shoulderR = _rig.FindBone("DEF-shoulder.R");
		_upperR = _rig.FindBone("DEF-upper_arm.R");
		_foreR = _rig.FindBone("DEF-forearm.R");
		_handR = _rig.FindBone("DEF-hand.R");

		if (_upperR < 0 || _foreR < 0 || _handR < 0 || _spine3 < 0 || _spine < 0)
		{
			GD.PushError("LanternHold: required arm or spine bones missing on skeleton");
			return;
		}

		// Finger bones (R hand) and cache their rest poses.
		int fIdx = 0;
		foreach (string finger in new[] { "index", "middle", "ring", "pinky" })
		{
			for (int joint = 1; joint <= 3; joint++)
			{
				int b = _rig.FindBone($"DEF-f_{finger}.0{joint}.R");
				_fingers[fIdx] = b;
				_restFingers[fIdx] = b >= 0 ? _rig.GetBoneRest(b).Basis.GetRotationQuaternion() : Quaternion.Identity;
				fIdx++;
			}
		}

		_restUpperR = _upperR >= 0 ? _rig.GetBoneRest(_upperR).Basis.GetRotationQuaternion() : Quaternion.Identity;
		_restForeR = _foreR >= 0 ? _rig.GetBoneRest(_foreR).Basis.GetRotationQuaternion() : Quaternion.Identity;
		_restHandR = _handR >= 0 ? _rig.GetBoneRest(_handR).Basis.GetRotationQuaternion() : Quaternion.Identity;

		_ready = true;
	}

	public void Configure(float hoistSeconds, float toggleSeconds, Vector3 chestPos, Vector3 hipPos)
	{
		_duration = Mathf.Max(hoistSeconds, 0.1f);
		_toggleSeconds = Mathf.Max(toggleSeconds, 0.1f);
		_chestOffset = chestPos;
		_hipOffset = hipPos;
	}

	public bool BeginPickup(Node3D lantern, float duration = 1.2f)
	{
		if (!_ready || Busy || !IsInstanceValid(lantern) || _rig == null) return false;
		_lantern = lantern;
		_scale = lantern.Scale;
		_found = _rig.GlobalTransform.AffineInverse() * lantern.GlobalTransform;
		_startHand = _rig.GetBoneGlobalPose(_handR).Origin;
		_gripped = false;
		_gesture = Gesture.Pickup;
		_duration = duration;
		_elapsed = 0;
		Busy = true;
		return true;
	}

	public bool Toggle(float duration = 0.55f)
	{
		if (!_ready || Busy || !HasLantern || _lantern == null || _rig == null) return false;
		_startHand = _rig.GetBoneGlobalPose(_handR).Origin;
		_gesture = IsEquipped ? Gesture.Stow : Gesture.Equip;
		_duration = duration;
		_elapsed = 0;
		Busy = true;
		return true;
	}

	public void Restore(Node3D lantern, bool equipped = true)
	{
		if (!_ready || _lantern != null) return;
		_lantern = lantern;
		_scale = lantern.Scale;
		HasLantern = true;
		IsEquipped = equipped;
		_lantern.Set("lit", equipped);
	}

	public void Advance(float delta)
	{
		if (Busy)
		{
			_elapsed = Mathf.Min(_elapsed + delta, _duration);
		}
	}

	public override void _ProcessModificationWithDelta(double delta)
	{
		if (_lantern == null || !IsInstanceValid(_lantern) || !_ready || _rig == null) return;

		float dt = (float)delta;
		UpdatePhysics(dt);

		if (!Busy)
		{
			if (IsEquipped)
			{
				ApplyChestWearTransform();
			}
			else
			{
				ApplyHipStowTransform();
			}
			return;
		}

		float t = Progress;
		switch (_gesture)
		{
			case Gesture.Pickup:
				ProcessPickupGesture(t, dt);
				break;
			case Gesture.Equip:
				ProcessEquipGesture(t, dt);
				break;
			case Gesture.Stow:
				ProcessStowGesture(t, dt);
				break;
		}
	}

	private void UpdatePhysics(float dt)
	{
		if (dt <= 0.0001f || _rig == null) return;
		Vector3 currentPos = _rig.GlobalPosition;
		Vector3 worldVel = (currentPos - _lastWorldPos) / dt;
		Vector3 worldAccel = (worldVel - _lastVelocity) / dt;
		_lastWorldPos = currentPos;
		_lastVelocity = worldVel;

		// Convert acceleration to local frame for pendulum sway.
		Vector3 localAccel = _rig.GlobalBasis.Inverse() * worldAccel;

		// Pendulum spring physics (natural frequency ~52.0, damping ~5.0).
		float k = 52.0f;
		float damping = 5.0f;
		Vector2 force = new Vector2(-localAccel.X * 0.10f, localAccel.Z * 0.12f);

		_swayVelocity += (force - _swayAngle * k - _swayVelocity * damping) * dt;
		_swayVelocity = _swayVelocity.Clamp(new Vector2(-3.5f, -3.5f), new Vector2(3.5f, 3.5f));
		_swayAngle += _swayVelocity * dt;
		_swayAngle = _swayAngle.Clamp(new Vector2(-0.25f, -0.25f), new Vector2(0.25f, 0.25f));
	}

	private void ApplyChestWearTransform()
	{
		if (_lantern == null || _rig == null || _spine3 < 0) return;
		Transform3D chestPose = _rig.GetBoneGlobalPose(_spine3);
		Vector3 anchor = chestPose * _chestOffset;

		// Upright orientation with forward facing and dynamic pendulum sway.
		Basis swayBasis = new Basis(Vector3.Right, _swayAngle.Y) * new Basis(Vector3.Forward, _swayAngle.X);
		Transform3D localT = new Transform3D(swayBasis.Scaled(_scale), anchor);

		_lantern.GlobalTransform = _rig.GetGlobalTransformInterpolated() * localT;
	}

	private void ApplyHipStowTransform()
	{
		if (_lantern == null || _rig == null || _spine < 0) return;
		Transform3D hipPose = _rig.GetBoneGlobalPose(_spine);
		Vector3 anchor = hipPose * _hipOffset;
		Basis hipRot = new Basis(Vector3.Forward, Mathf.DegToRad(12.0f)) * new Basis(Vector3.Up, Mathf.DegToRad(15.0f));
		Transform3D localT = new Transform3D(hipRot.Scaled(_scale), anchor);

		_lantern.GlobalTransform = _rig.GetGlobalTransformInterpolated() * localT;
	}

	private void ProcessPickupGesture(float t, float dt)
	{
		if (_rig == null || _spine3 < 0) return;

		// Top wire handle height relative to lantern base.
		float handleHeight = 0.26f * _scale.Y;
		Vector3 targetGrip = _found.Origin + new Vector3(0.0f, handleHeight, 0.0f);

		// Target chest carry socket in skeleton space.
		Transform3D chestPose = _rig.GetBoneGlobalPose(_spine3);
		Vector3 chestSocket = chestPose * _chestOffset + new Vector3(0.0f, handleHeight, 0.0f);

		Vector3 handTarget;
		float armWeight = 1.0f;
		float flexWeight = 0.0f;
		float curlWeight = 0.0f;

		if (t < 0.36f)
		{
			// Phase 1: Reaching down toward lantern handle.
			float reachP = Ease(t / 0.36f);
			handTarget = _startHand.Lerp(targetGrip, reachP);
			armWeight = reachP;
			flexWeight = Mathf.Sin(reachP * Mathf.Pi * 0.5f);
			curlWeight = Ease((t - 0.20f) / 0.16f);

			// Lantern resting on stand / surface:
			_lantern!.GlobalTransform = _rig.GetGlobalTransformInterpolated() * _found;
		}
		else if (t < 0.82f)
		{
			// Phase 2: Lifting upward in a smooth arc toward chest socket.
			float liftP = Ease((t - 0.36f) / 0.46f);
			Vector3 midArc = (targetGrip + chestSocket) * 0.5f + new Vector3(-0.02f, 0.08f, 0.05f);
			handTarget = targetGrip.Lerp(midArc, liftP * 1.5f).Lerp(chestSocket, liftP);
			armWeight = 1.0f;
			flexWeight = 1.0f - liftP;
			curlWeight = 1.0f;

			// Lantern moves with hand:
			Vector3 handAt = _rig.GetBoneGlobalPose(_handR).Origin;
			Vector3 lanternPos = handAt - new Vector3(0.0f, handleHeight, 0.0f);
			Transform3D localT = new Transform3D(Basis.Identity.Scaled(_scale), lanternPos);
			_lantern!.GlobalTransform = _rig.GetGlobalTransformInterpolated() * localT;
		}
		else
		{
			// Phase 3: Settled at chest harness; hand relaxes away.
			float settleP = Ease((t - 0.82f) / 0.18f);
			handTarget = chestSocket.Lerp(_startHand, settleP * 0.4f);
			armWeight = 1.0f - settleP;
			flexWeight = 0.0f;
			curlWeight = 1.0f - settleP;

			// Lantern settled on front chest harness:
			ApplyChestWearTransform();
			if (!_gripped)
			{
				_gripped = true;
				HasLantern = true;
				IsEquipped = true;
				_lantern!.Set("lit", true);
			}
		}

		// Apply natural torso flexion without accumulating state across frames.
		FlexSpine(flexWeight * 0.10f);

		// Arm IK solve.
		SolveRightArm(handTarget, armWeight);

		// Finger curling around handle.
		CurlFingers(curlWeight);

		if (t >= 1.0f)
		{
			Busy = false;
			HasLantern = true;
			IsEquipped = true;
			ResetArm();
			EmitSignal(SignalName.Hoisted);
		}
	}

	private void ProcessEquipGesture(float t, float dt)
	{
		if (_rig == null || _spine < 0 || _spine3 < 0) return;
		Vector3 hipSocket = _rig.GetBoneGlobalPose(_spine) * _hipOffset;
		Vector3 chestSocket = _rig.GetBoneGlobalPose(_spine3) * _chestOffset;

		float p = Ease(t);
		Vector3 target = hipSocket.Lerp(chestSocket, p);
		SolveRightArm(target, Mathf.Sin(p * Mathf.Pi) * 0.75f);

		if (t < 0.5f)
		{
			ApplyHipStowTransform();
		}
		else
		{
			ApplyChestWearTransform();
			if (!IsEquipped)
			{
				IsEquipped = true;
				_lantern!.Set("lit", true);
				EmitSignal(SignalName.Toggled, true);
			}
		}

		if (t >= 1.0f)
		{
			Busy = false;
			ResetArm();
		}
	}

	private void ProcessStowGesture(float t, float dt)
	{
		if (_rig == null || _spine < 0 || _spine3 < 0) return;
		Vector3 hipSocket = _rig.GetBoneGlobalPose(_spine) * _hipOffset;
		Vector3 chestSocket = _rig.GetBoneGlobalPose(_spine3) * _chestOffset;

		float p = Ease(t);
		Vector3 target = chestSocket.Lerp(hipSocket, p);
		SolveRightArm(target, Mathf.Sin(p * Mathf.Pi) * 0.75f);

		if (t < 0.5f)
		{
			ApplyChestWearTransform();
		}
		else
		{
			ApplyHipStowTransform();
			if (IsEquipped)
			{
				IsEquipped = false;
				_lantern!.Set("lit", false);
				EmitSignal(SignalName.Toggled, false);
			}
		}

		if (t >= 1.0f)
		{
			Busy = false;
			ResetArm();
		}
	}

	public void AttachChest()
	{
		if (_lantern == null) return;
		Busy = false;
		HasLantern = true;
		IsEquipped = true;
		_lantern.Set("lit", true);
		ResetArm();
		ApplyChestWearTransform();
	}

	public void AttachHip()
	{
		if (_lantern == null) return;
		Busy = false;
		HasLantern = true;
		IsEquipped = false;
		_lantern.Set("lit", false);
		ResetArm();
		ApplyHipStowTransform();
	}

	public void ResetArm()
	{
		if (_rig == null) return;
		if (_upperR >= 0) _rig.SetBonePoseRotation(_upperR, _restUpperR);
		if (_foreR >= 0) _rig.SetBonePoseRotation(_foreR, _restForeR);
		if (_handR >= 0) _rig.SetBonePoseRotation(_handR, _restHandR);
		CurlFingers(0.0f);
	}

	private void SolveRightArm(Vector3 target, float weight)
	{
		if (weight <= 0.001f || _rig == null) return;
		int upperId = _upperR, foreId = _foreR, handId = _handR;
		var upper = _rig.GetBoneGlobalPose(upperId);
		var fore = _rig.GetBoneGlobalPose(foreId);
		var hand = _rig.GetBoneGlobalPose(handId);

		Vector3 shoulder = upper.Origin;
		float a = shoulder.DistanceTo(fore.Origin);
		float b = fore.Origin.DistanceTo(hand.Origin);
		if (a < 0.01f || b < 0.01f) return;

		Vector3 toward = target - shoulder;
		float distance = Mathf.Clamp(toward.Length(), Mathf.Abs(a - b) + 0.005f, a + b - 0.005f);
		Vector3 direction = toward.Normalized();

		// Pole vector: right elbow points outward (-X) and slightly back and down.
		Vector3 pole = new Vector3(-1.0f, -0.1f, 0.15f);
		Vector3 perpendicular = (pole - direction * pole.Dot(direction)).Normalized();
		float along = (a * a - b * b + distance * distance) / (2.0f * distance);
		Vector3 elbow = shoulder + direction * along + perpendicular * Mathf.Sqrt(Mathf.Max(a * a - along * along, 0.0f));

		Quaternion turnUpper = new((fore.Origin - shoulder).Normalized(), (elbow - shoulder).Normalized());
		SetRotation(upperId, upper.Basis.GetRotationQuaternion().Slerp(turnUpper * upper.Basis.GetRotationQuaternion(), weight));

		fore = _rig.GetBoneGlobalPose(foreId);
		hand = _rig.GetBoneGlobalPose(handId);
		Quaternion turnFore = new((hand.Origin - fore.Origin).Normalized(), (shoulder + direction * distance - fore.Origin).Normalized());
		SetRotation(foreId, fore.Basis.GetRotationQuaternion().Slerp(turnFore * fore.Basis.GetRotationQuaternion(), weight));
	}

	private void FlexSpine(float amount)
	{
		if (_rig == null || _spine3 < 0) return;
		if (amount > 0.001f)
		{
			Quaternion currentPose = _rig.GetBonePoseRotation(_spine3);
			Quaternion pitch = new(Vector3.Right, amount);
			_rig.SetBonePoseRotation(_spine3, (currentPose * pitch).Normalized());
			if (_head >= 0)
			{
				Quaternion currentHead = _rig.GetBonePoseRotation(_head);
				_rig.SetBonePoseRotation(_head, (currentHead * new Quaternion(Vector3.Right, -amount * 1.2f)).Normalized());
			}
		}
	}

	private void CurlFingers(float weight)
	{
		if (_rig == null) return;
		float angle = Mathf.DegToRad(58.0f) * Mathf.Clamp(weight, 0.0f, 1.0f);
		Quaternion curl = new(Vector3.Right, angle);
		for (int i = 0; i < 12; i++)
		{
			int bone = _fingers[i];
			if (bone >= 0)
			{
				_rig.SetBonePoseRotation(bone, _restFingers[i].Slerp(_restFingers[i] * curl, weight));
			}
		}
	}

	private void SetRotation(int bone, Quaternion rotation)
	{
		if (_rig == null) return;
		int parent = _rig.GetBoneParent(bone);
		Quaternion parentRot = parent >= 0 ? _rig.GetBoneGlobalPose(parent).Basis.GetRotationQuaternion() : Quaternion.Identity;
		_rig.SetBonePoseRotation(bone, (parentRot.Inverse() * rotation).Normalized());
	}

	private static float Ease(float v)
	{
		float x = Mathf.Clamp(v, 0.0f, 1.0f);
		return x * x * (3.0f - 2.0f * x);
	}
}
