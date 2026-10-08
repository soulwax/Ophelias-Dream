using Godot;

/// <summary>Contact-aware reach, shoulder lift, seating and release, after the gait layers.</summary>
[GlobalClass]
public partial class BowHoist : SkeletonModifier3D
{
	[Signal] public delegate void HoistedEventHandler();
	public bool Busy { get; private set; }
	public bool HasBow { get; private set; }
	public float Progress => _duration > 0 ? _elapsed / _duration : 0;
	public float HandError { get; private set; }
	private Skeleton3D _rig = null!;
	private Node3D? _bow;
	private BoneAttachment3D _back = null!;
	private int _upper, _fore, _hand, _chest;
	private readonly int[] _fingers = new int[12];
	private Vector3 _startHand;
	private Transform3D _found;
	private Transform3D _carry;
	private float _elapsed, _duration;
	private bool _ready;
	private bool _gripped;

	public override void _Ready()
	{
		_rig = GetSkeleton();
		if (_rig == null) return;
		_upper = _rig.FindBone("DEF-upper_arm.R");
		_fore = _rig.FindBone("DEF-forearm.R");
		_hand = _rig.FindBone("DEF-hand.R");
		_chest = _rig.FindBone("DEF-spine.003");
		if (_upper < 0 || _fore < 0 || _hand < 0 || _chest < 0)
		{
			GD.PushError("BowHoist: required elf arm/chest bones missing");
			return;
		}
		int index = 0;
		foreach (string finger in new[] { "index", "middle", "ring", "pinky" })
			for (int joint = 1; joint <= 3; joint++)
				_fingers[index++] = _rig.FindBone($"DEF-f_{finger}.0{joint}.R");
		_back = new BoneAttachment3D { Name = "BowBack", BoneName = "DEF-spine.003" };
		_rig.AddChild(_back);
		_ready = true;
	}

	public void Configure(float duration, Vector3 backPosition, float backRoll)
	{
		_duration = Mathf.Max(duration, 0.1f);
		_carry = new Transform3D(new Basis(Vector3.Back, backRoll), backPosition);
	}

	public bool Begin(Node3D bow)
	{
		if (!_ready || Busy || HasBow || !IsInstanceValid(bow)) return false;
		_bow = bow;
		_found = _rig.GlobalTransform.AffineInverse() * bow.GlobalTransform;
		_startHand = _rig.GetBoneGlobalPose(_hand).Origin;
		_gripped = false;
		_elapsed = 0;
		Busy = true;
		return true;
	}

	// Called by Player's physics tick only while PLAYING. Menus/journal freeze the gesture.
	public void Advance(float delta)
	{
		if (Busy) _elapsed = Mathf.Min(_elapsed + delta, _duration);
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
		if (!Busy || _bow == null || !IsInstanceValid(_bow)) return;
		float t = Mathf.Clamp(Progress, 0, 1);
		if (!_gripped)
			_found = _rig.GlobalTransform.AffineInverse() * _bow.GlobalTransform;
		// Lean slightly toward the found grip, then straighten under the lift.
		float lean = Ease(t / 0.16f) * (1 - Ease((t - 0.2f) / 0.3f));
		RotateGlobal(_chest, new Quaternion(Vector3.Right, 0.14f * lean));
		Vector3 raised = new(-0.46f, 1.78f, 0.32f);
		Vector3 over = new(-0.38f, 2.02f, -0.08f);
		Quaternion from = _found.Basis.Orthonormalized().GetRotationQuaternion();
		Quaternion to = _carry.Basis.GetRotationQuaternion();
		var rotation = from.Slerp(to, Ease((t - 0.43f) / 0.37f));
		var bowFrame = new Basis(rotation);
		// Wrist is behind the palm: grasp the handle, not with the wrist joint.
		var handFrame = new Basis(bowFrame.Y, bowFrame.X, -bowFrame.Z);
		Vector3 gripOffset = handFrame.Y * 0.085f;
		Vector3 target;
		if (t < 0.12f) target = _startHand.Lerp(_found.Origin - gripOffset, Ease(t / 0.12f));
		else if (t < 0.43f) target = _found.Origin.Lerp(raised, Ease((t - 0.12f) / 0.31f)) - gripOffset;
		else if (t < 0.6f) target = raised.Lerp(over, Ease((t - 0.43f) / 0.17f)) - gripOffset;
		else if (t < 0.8f) target = over.Lerp(_carry.Origin, Ease((t - 0.6f) / 0.2f)) - gripOffset;
		else target = _carry.Origin - gripOffset;
		float weight = 1 - Ease((t - 0.82f) / 0.18f);
		SolveArm(target, weight);
		var handPose = _rig.GetBoneGlobalPose(_hand);
		SetGlobalRotation(_hand, handPose.Basis.GetRotationQuaternion().Slerp(
			handFrame.GetRotationQuaternion(), Ease(t / 0.12f) * weight));
		float grip = Ease((t - 0.09f) / 0.04f) * (1 - Ease((t - 0.79f) / 0.08f));
		Vector3 curlAxis = _rig.GetBoneGlobalPose(_hand).Basis.X.Normalized();
		foreach (int finger in _fingers)
			if (finger >= 0)
				RotateGlobal(finger, new Quaternion(curlAxis, 0.85f * grip));

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
			Vector3 seated = handAt.Lerp(_carry.Origin, Ease((t - 0.74f) / 0.06f));
			_bow.Transform = new Transform3D(new Basis(rotation).Scaled(_found.Basis.Scale), seated);
		}
		else if (t >= 0.8f && !HasBow)
		{
			AttachBack();
			HasBow = true;
		}
		if (t >= 1)
		{
			Busy = false;
			EmitSignal(SignalName.Hoisted);
		}
	}

	private void AttachBack()
	{
		if (_bow == null) return;
		// Carry is in skeleton metres; the parent rig already owns model scale.
		var bone = _rig.GetBoneGlobalPose(_chest);
		_back.Transform = bone;
		_bow.Reparent(_back, false);
		_bow.Transform = bone.AffineInverse() * _carry;
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
		// Elbow stays to her right, rather than flipping across the torso.
		Vector3 pole = new Vector3(-1, 0.1f, 0.15f);
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
