using Godot;

/// <summary>Evaluated hand attachment and a quiet carrying pose after BowHoist.</summary>
[GlobalClass]
public partial class CarryHold : SkeletonModifier3D
{
	public string Pose { get; set; } = "hand";
	public float Weight { get; set; }
	public Transform3D HandSocket { get; private set; } = Transform3D.Identity;
	private float _pickSeconds = 0.45f;
	private Vector3 _handTarget, _armfulTarget, _pole;
	private Skeleton3D? _rig;
	private Node3D? _visual;
	private Vector3 _scale = Vector3.One;
	private float _blend;
	private readonly int[] _bones = new int[6];

	public override void _Ready()
	{
		var tune = GD.Load<Script>("res://scripts/tune.gd").GetScriptConstantMap();
		_pickSeconds = tune["CARRY_PICK_SECONDS"].AsSingle();
		_handTarget = tune["CARRY_HAND_TARGET"].AsVector3();
		_armfulTarget = tune["CARRY_ARMFUL_TARGET"].AsVector3();
		_pole = tune["CARRY_ARM_POLE"].AsVector3();
		_rig = GetSkeleton();
		if (_rig == null) return;
		int i = 0;
		foreach (string side in new[] { "R", "L" })
			foreach (string part in new[] { "upper_arm", "forearm", "hand" })
				_bones[i++] = _rig.FindBone($"DEF-{part}.{side}");
	}

	public void Attach(Node3D visual, bool immediate = false)
	{
		_visual = visual;
		_scale = visual.GlobalBasis.Scale;
		if (immediate) _blend = Mathf.Clamp(Weight, 0, 1);
	}

	public void Detach() { _visual = null; Weight = 0; }

	public override void _ProcessModificationWithDelta(double delta)
	{
		if (_rig == null || _bones[0] < 0 || _bones[1] < 0 || _bones[2] < 0) return;
		_blend = Mathf.MoveToward(_blend, Mathf.Clamp(Weight, 0, 1), (float)delta / Mathf.Max(_pickSeconds, 0.01f));
		float amount = Mathf.SmoothStep(0, 1, _blend);
		if (amount > 0)
		{
			SolveArm(0, Pose == "armful" ? _armfulTarget : _handTarget, amount);
			if (Pose == "armful" && _bones[3] >= 0 && _bones[4] >= 0 && _bones[5] >= 0)
				SolveArm(3, Mirror(_armfulTarget), amount);
		}
		// Modifiers run in the idle frame (the skeleton's default callback mode), where the
		// skin is drawn at the rig's interpolated transform times these bone poses. The
		// visual has interpolation off and is placed from that same interpolated rig, so it
		// sits on the drawn palm instead of a physics tick behind or ahead of it.
		Transform3D rig = _rig.GetGlobalTransformInterpolated();
		HandSocket = rig * _rig.GetBoneGlobalPose(_bones[2]);
		if (_visual == null || !IsInstanceValid(_visual)) return;
		Vector3 origin = HandSocket.Origin;
		if (Pose == "armful" && _bones[5] >= 0)
			origin = origin.Lerp((rig * _rig.GetBoneGlobalPose(_bones[5])).Origin, 0.5f);
		// Upright props follow the evaluated palm, after every arm modifier.
		_visual.GlobalTransform = new Transform3D(rig.Basis.Orthonormalized().Scaled(_scale), origin);
	}

	private void SolveArm(int first, Vector3 target, float weight)
	{
		var rig = _rig!;
		int upperId = _bones[first], foreId = _bones[first + 1], handId = _bones[first + 2];
		var upper = rig.GetBoneGlobalPose(upperId);
		var fore = rig.GetBoneGlobalPose(foreId);
		var hand = rig.GetBoneGlobalPose(handId);
		Vector3 shoulder = upper.Origin;
		float a = shoulder.DistanceTo(fore.Origin), b = fore.Origin.DistanceTo(hand.Origin);
		if (a < 0.01f || b < 0.01f) return;
		Vector3 toward = target - shoulder;
		float distance = Mathf.Clamp(toward.Length(), Mathf.Abs(a - b) + 0.005f, a + b - 0.005f);
		Vector3 direction = toward.Normalized();
		Vector3 pole = first == 0 ? _pole : Mirror(_pole);
		Vector3 perpendicular = (pole - direction * pole.Dot(direction)).Normalized();
		float along = (a * a - b * b + distance * distance) / (2 * distance);
		Vector3 elbow = shoulder + direction * along + perpendicular * Mathf.Sqrt(Mathf.Max(a * a - along * along, 0));
		Quaternion turn = new((fore.Origin - shoulder).Normalized(), (elbow - shoulder).Normalized());
		SetRotation(upperId, upper.Basis.GetRotationQuaternion().Slerp(turn * upper.Basis.GetRotationQuaternion(), weight));
		fore = rig.GetBoneGlobalPose(foreId);
		hand = rig.GetBoneGlobalPose(handId);
		turn = new Quaternion((hand.Origin - fore.Origin).Normalized(), (shoulder + direction * distance - fore.Origin).Normalized());
		SetRotation(foreId, fore.Basis.GetRotationQuaternion().Slerp(turn * fore.Basis.GetRotationQuaternion(), weight));
	}

	private static Vector3 Mirror(Vector3 v) => new(-v.X, v.Y, v.Z);

	private void SetRotation(int bone, Quaternion rotation)
	{
		var rig = _rig!;
		int parent = rig.GetBoneParent(bone);
		Quaternion parentRotation = parent >= 0 ? rig.GetBoneGlobalPose(parent).Basis.GetRotationQuaternion() : Quaternion.Identity;
		rig.SetBonePoseRotation(bone, (parentRotation.Inverse() * rotation).Normalized());
	}
}
