rollout XSIExport "XSI Export" rolledUp:false silentErrors:false (
	groupBox objects "Objects" pos:[10,10] width:150 height:200
	checkbox meshs "Meshs" pos:[25,35]
	checkbox animations "Animations" pos:[25,56]
	checkbox bones "Bones" pos:[25,77]
	checkbox pointWeights "Point Weights" pos:[25,98]
	checkbox lights "Lights" pos:[25,119]
	checkbox ikChains "IK Chains" pos:[25,140]
	checkbox baseposeTransforms "Basepose Transforms" pos:[25,161]
	checkbox srtTransforms "SRT Transforms" pos:[25,182]
	groupBox options "Options" pos:[170,10] width:260 height:200
	checkbox bonesAsNulls "Bones as Nulls" pos:[185,40]
	checkbox flattenHierarchy "Flatten Hierarchy" pos:[320,40]
	checkbox animationSubRange "Animation Sub-Range" enabled:false pos:[185,61]
	checkbox rescale "Rescale" pos:[320,61]
	edittext startFrame "Frame:" pos:[235,85] enabled:false bold:false fieldWidth:34 text:(((animationRange.start as integer)/ticksPerFrame) as string) height:20
	edittext endFrame "to frame:" pos:[310,85] enabled: false bold:false fieldWidth:34 text:(((animationRange.end as integer)/ticksPerFrame) as string) height:20
	checkbox useLocalFilenamesForTextures "Use Local Filenames For Textures" pos:[185,119]
	checkbox generateShaderNamesPSet "Generate Shader Names PSet" pos:[185,140]
	edittext stripOutPathBefore "Strip out path before:" pos:[202,161] enabled:false bold:false fieldWidth:215 height:20 text:"\\base\\" labelOnTop:true
	button okButton "OK" pos:[270,220] width:70
	button cancel "Cancel" pos:[360,220] width:70
	
	on animations changed newState do (
		animationSubRange.enabled = newState
		if animationSubRange.checked do \
			startFrame.enabled = endFrame.enabled = newState			
	)
	
	on animationSubRange changed newState do \
		startFrame.enabled = endFrame.enabled = newState
	
	on generateShaderNamesPSet changed newState do \
		stripOutPathBefore.enabled = newState
	
	local T = matrix3 x_axis y_axis y_axis [0,0,0]

	fn trim s = (
		local tmp = ""
		for x in (filterString s " ") do tmp += s + "_"
		return substring tmp 1 (tmp.count-1)
	)
	
	fn SI_FileInfo = (
		local projectName = if fileProperties.findProperty #summary "Title" > 0 then fileProperties.getPropertyValue #summary 1 else ""
		local userName = if fileProperties.findProperty #summary "Author" > 0 then fileProperties.getPropertyValue #summary 3 else ""
		
		format "SI_FileInfo {\n"
		for x in #(projectName,userName,localTime,"gmax XSI Export") do format "\"%\",\n" x
		format "}\n"
	)
	
	fn SI_Scene = (
		global sceneName = trim (getFileNameFile maxFileName)
		if "" == sceneName do sceneName = "Untitled"
		local start = if animationSubRange.checked then startFrame.text else (animationRange.start / ticksPerFrame)
		local end = if animationSubRange.checked then endFrame.text else (animationRange.end / ticksPerFrame)
		format "SI_Scene % {\n\"FRAMES\",\n%,%,\n%,\n}\n" sceneName (start as float) (end as float) (frameRate as float)
	)
	
	fn SI_CoordinateSystem = (
		format "SI_CoordinateSystem {\n1,\n0,\n1,\n0,\n2,\n5,\n}\n"
	)
	
	fn SI_Angle = (
		format "SI_Angle {\n0,\n}\n"
	)
	
	fn SI_Ambience = (
		format "SI_Ambience {\n%,\n%,\n%,\n}\n" ambientColor.red ambientColor.green ambientColor.blue
	)
	
	fn SI_Texture2D map = (
		local width = map.bitmap.width
		local height = map.bitmap.height
		format "SI_Texture2D {\n\"%\",\n" map.fileName
		local mappingTypes = #(4,0,1,2,6,5,3,7)
		-- Texture Explicit         4
		-- Texture Vertex           0
		-- Texture Planar Object  1
		-- Texture Planar World   2
		-- Env Spherical              6
		-- Env Cylindrical            5
		-- Env Shrink                  3
		-- Env Screen                 7
		format "%,\n" mappingTypes[1+map.coords.mappingType*4+map.coords.mapping]
		format "%,\n%,\n" width height
		local cropU = [0,width-1]
		format "%,\n%,\n" cropU.x cropU.y
		local cropV = [0,height-1]
		format "%,\n%,\n" cropV.x cropV.y
		format "0,\n" -- UVSwap
		format "%,\n%,\n" map.coords.U_Tiling map.coords.V_Tiling
		format "%,\n%,\n1,\n1,\n" (if map.coords.U_Mirror then 1 else 0) (if map.coords.V_Mirror then 1 else 0) -- Scale
		format "%,\n%,\n" map.coords.U_Offset map.coords.V_Offset
		format "1,0,0,0,\n" -- projection matrix
		format "0,1,0,0,\n"
		format "0,0,1,0,\n"
		format "0,0,0,1,\n"
		format "3,\n1,\n0.75,\n1,\n0,\n%,\n0,\n%,\n"  map.output.output_amount map.output.Bump_Amount
		format "}\n"
	)
	
	fn SI_Material mtl = (
		format "SI_Material % {\n" (trim mtl.name)
		local faceColor = mtl.diffuse/255
		format "%,%,%,%,\n" faceColor.r faceColor.g faceColor.b faceColor.a
		format "%,\n" mtl.specularLevel
		local specularColor = mtl.specular/255
		format "%,%,%,\n" specularColor.r specularColor.g specularColor.b
		local emissiveColor = if mtl.useSelfIllumColor then mtl.selfIllumColor/255 else faceColor
		format "%,%,%,\n" emissiveColor.r emissiveColor.g emissiveColor.b
		local shadingModel = case mtl.shaderByName of (
			"Blinn":3
			"Metal":1
			"Phong":2
			default:1
		)
		format "%,\n" shadingModel
		local ambient = mtl.ambient/255
		format "%,%,%,\n" ambient.r ambient.g ambient.b
		for map in mtl.maps where undefined != map do SI_Texture2D map
		format "}\n"
	)
	
	fn SI_MaterialLibrary = (
		format "SI_MaterialLibrary MATLIB-% {\n%,\n" sceneName sceneMaterials.count
		for mtl in sceneMaterials do SI_Material mtl
		format "}\n"
	)
	
	fn SI_Visibility nd = (
		format "SI_Visibility {\n%,\n}\n" (if nd.visibility then 1 else 0)
	)
	
	fn SI_Transforms nd = (
		local scal = nd.transform.scale*T
		local rot = nd.transform.rotation*T
		local trans = nd.transform.translation*T
		
		if srtTransforms.checked do (
			format "SI_Transform SRT-% {\n" (trim nd.name)
			for x in #(scal.x,scal.y,scal.z,rot.x,rot.y,rot.z,trans.x,trans.y,trans.z) do format "%,\n" x
			format "}\n"
		)
		
		if baseposeTransforms.checked do (
			format "SI_Transform BASEPOSE-% {\n" (trim nd.name)
			for x in #(scal.x,scal.y,scal.z,rot.x,rot.y,rot.z,trans.x,trans.y,trans.z) do format "%,\n" x
			format "}\n"
		)
	)
	
	fn SI_Shape nm msh = (
		format "SI_Shape SHP-%-ORG {\n" nm
		local nbShapeArrays = 2
		if msh.numtverts > 0 do nbShapeArrays += 1
		if msh.numcpvverts > 0 do nbShapeArrays += 1
		format "\"ORDERED\",\n"
		format "%,\n\"POSITION\",\n" msh.numverts
		for v in msh.verts do (
			local u = v.pos*T
			format "%,%,%,\n" u.x u.y u.z
		)
		format "%,\n\"NORMAL\",\n" msh.numverts
		for i=1 to msh.numverts do (
			local u = (getNormal msh i)*T
			format "%,%,%,\n" u.x u.y u.z
		)
		if msh.numcpvverts > 0 do (
			format "%,\n\"COLOR\",\n" msh.numcpvverts
			for i=1 to msh.numcpvverts do (
				local col = (getVertColor msh i)/255
				format "%,%,%,%,\n" col.r col.g col.b col.a
			)
		)
		if msh.numtverts > 0 do (
			format "%,\n\"TEX_COORD_UV\",\n" msh.numtverts
			for i=1 to msh.numtverts do (
				local uvw = (getTVert msh i)*T
				format "%,%,\n" uvw.x uvw.y
			)
		)
		format "}\n"
	)
	
	fn SI_TriangleList msh = (
		format "SI_TriangleList {\n%,\n" msh.numfaces
		format "\"NORMAL"
		if msh.numcpvverts > 0 do format "|COLOR"
		if msh.numtverts > 0 do format "|TEX_COORD_UV"
		format "\",\n"
		-- TODO objectMtlName?
		for i=1 to msh.numfaces do (
			local indices = (getFace msh i) - [1,1,1]
			format "%,%,%,\n" (indices.x as integer) (indices.y as integer) (indices.z as integer)
		)
		for i=1 to msh.numfaces do (
			local indices = (getFace msh i) - [1,1,1]
			format "%,%,%,\n" (indices.x as integer) (indices.y as integer) (indices.z as integer)
		)
		if msh.numcpvverts > 0 do (
			format "\n"
			for i=1 to msh.numfaces do (
				local indices = (getVCFace msh i) - [1,1,1]
				format "%,%,%,\n" (indices.x as integer) (indices.y as integer) (indices.z as integer)
			)
		)
		if msh.numtverts > 0 do (
			format "\n"
			for i=1 to msh.numfaces do (
				local indices = (getTVFace msh i) - [1,1,1]
				format "%,%,%,\n" (indices.x as integer) (indices.y as integer) (indices.z as integer)
			)
		)
		format "}\n"
	)
	
	fn SI_GlobalMaterial nd = (
		if undefined != nd.material do \
			format "SI_GlobalMaterial {\n\"NODE\",\n\"%\",\n}\n" (trim nd.material.name)
	)
	
	fn SI_Mesh nm msh = (
		format "SI_Mesh MSH-% {\n" nm
		SI_Shape nm msh
		SI_TriangleList msh
	)
	
	fn SI_Model nd = (
		local nm = trim nd.name
		format "SI_Model % {\n" nm
		SI_GlobalMaterial nd
		SI_Transforms nd
		SI_Visibility nd
		
		case classOf nd of (
			BoneGeometry: (
				--  TODO
			)
			TargetObject: (
				-- Do nothing.
			)
			Box: SI_Mesh nm nd.mesh
			Dummy: (
				format  "SI_Null % {\n}\n" nm
			)
		)
		
		if flattenHierarchy.checked then (
			format "}\n"
			for child in nd.children do SI_Model child
		) else (
			for child in nd.children do SI_Model child
			format "}\n"
		)
	)
	
	fn SI_EnvelopeList=(
		if pointWeights.checked do (		
			local envObjs = for obj in $geometry where (undefined != obj.modifiers[#skin]) collect obj
			local nEnvelopes = 0
			for obj in envObjs do nEnvelopes += (skinOps.getNumberBones obj.skin)
			
			format "SI_EnvelopeList {\n%,\n" nEnvelopes
			max modify mode
			for obj in envObjs do (
				select obj
				
				local iVertices = skinOps.getNumberVertices obj.skin
				
				for i in 1 to (skinOps.getNumberBones obj.skin) do (
					local 
					format "SI_Envelope {\n"
					format "\"%\",\n" (trim obj.name)
					format "\"%\",\n" (trim (skinOps.getBoneName obj.skin i 0))
					format "%,\n" iVertices
					for j in 1 to iVertices do (
						format "%,%,\n" (j-1) (skinOps.getVertexWeight obj.skin j i)
					)
				)
			)
			format "}\n"
		)
	)
	
	on okButton pressed do (
		clearListener()
		format "xsi 0300txt 0032\n"
		SI_FileInfo()
		SI_Scene()
		SI_CoordinateSystem()
		SI_Angle()
		SI_Ambience()
		SI_MaterialLibrary()
		for nd in rootNode.children do SI_Model nd
		SI_EnvelopeList()
	)
	
	on cancel pressed do closeRolloutFloater xsiExporter
)

if xsiExporter != undefined do closeRolloutFloater xsiExporter
global xsiExporter = newRolloutFloater "XSI Export" 467 308
addRollout XSIExport xsiExporter