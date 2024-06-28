#include "object3d.hlsli"

struct Material
{
    float4 color;
    int enableLighting;
    float4x4 uvTransform;
    float shininess;
};

struct DirectionLight
{
    float4 color;
    float3 direction;
    float intensity;
};

struct PointLight
{
    float4 color; // ライトの色
    float3 position; // ライトの位置
    float intensity; // 輝度
    float radius; // ライトの届く最大距離
    float decay; // 減衰率
    float padding[2];
};

struct Camera
{
    float3 worldPosition;
};

ConstantBuffer<Material> gMaterial : register(b0);

ConstantBuffer<DirectionLight> gDirectionalLight : register(b1);

ConstantBuffer<Camera> gCamera : register(b2);

ConstantBuffer<PointLight> gPointLight : register(b3);

Texture2D<float4> gTexture : register(t0);

SamplerState gSampler : register(s0);

struct PixelShaderOutput
{
    float4 color : SV_TARGET0;
};

PixelShaderOutput main(VertexShaderOutput input)
{
    PixelShaderOutput output;
    float4 transformedUV = mul(float4(input.texcoord,0.0f, 1.0f), gMaterial.uvTransform);
    float4 textureColor = gTexture.Sample(gSampler, transformedUV.xy);
    
    if (textureColor.a == 0.0)
    {
        discard;
    }
    
    if (gMaterial.enableLighting != 0)
    {
        // directinalLightの処理
        float NdotL = dot(normalize(input.normal), -gDirectionalLight.direction);
        
        float cos = pow(NdotL * 0.5f + 0.5f, 2.0f);
        
        //output.color.rgb = gMaterial.color.rgb * textureColor.rgb * gDirectionalLight.color.rgb * cos * gDirectionalLight.intensity;
        // output.color.a = gMaterial.color.a * textureColor.a;
       
        float3 reflectLight = reflect(gDirectionalLight.direction, normalize(input.normal));
        
        float3 toEye = normalize(gCamera.worldPosition - input.worldPosition);
        
        //float RdotE = dot(reflectLight, toEye);
        
        float3 halfVector = normalize(-gDirectionalLight.direction + toEye);
        
        float NDotH = dot(normalize(input.normal), halfVector);
        
        float specularPow = pow(saturate(NDotH), gMaterial.shininess);
       
        
        
     // 鏡面反射
        float3 specularDirectionLight = gDirectionalLight.color.rgb * gDirectionalLight.intensity * specularPow;// * float3(1.0f, 1.0f, 1.0f);
    
        // 拡散反射
        float3 diffuseDirectionLight = gMaterial.color.rgb * textureColor.rgb * gDirectionalLight.color.rgb * cos * gDirectionalLight.intensity;
        
        
        // PointLightの処理
        
        float distance = length(gPointLight.position - input.worldPosition); // ポイントライトへの距離
        
        float factor = pow(saturate(-distance / gPointLight.radius + 1.0),gPointLight.decay);

        float3 pointLightDirection = normalize(input.worldPosition - gPointLight.position);
        
         ////////////
        
        reflectLight = reflect(pointLightDirection, normalize(input.normal));
        
        toEye = normalize(gCamera.worldPosition - input.worldPosition);
        
        halfVector = normalize(-pointLightDirection + toEye);
        
        NDotH = dot(normalize(input.normal), halfVector);
        
        specularPow = pow(saturate(NDotH), gMaterial.shininess);
        
        ////////
        
        NdotL = dot(normalize(input.normal), -pointLightDirection);
        
        cos = pow(NdotL * 0.5f + 0.5f, 2.0f);
        
        halfVector = normalize(-pointLightDirection + toEye);
        
        NDotH = dot(normalize(input.normal), halfVector);
        
        specularPow = pow(saturate(NDotH), gMaterial.shininess);
        
        //鏡面反射

        float3 specularPointLight = gPointLight.color.rgb * gPointLight.intensity * specularPow * factor;// * float3(1.0f, 1.0f, 1.0f);
    
        // 拡散反射
        float3 diffusePointLight = gMaterial.color.rgb * textureColor.rgb * gPointLight.color.rgb * cos * gPointLight.intensity * factor;
        
        
        // 拡散反射＋鏡面反射
        output.color.rgb = diffuseDirectionLight + specularDirectionLight + diffusePointLight + specularPointLight;
        
        // アルファは今まで道理
        output.color.a = gMaterial.color.a * textureColor.a;
    }
    else
    {
        output.color = gMaterial.color * textureColor;
    }
    
    if (textureColor.a <= 0.5)
    {
        discard;
    }
        
    if (output.color.a == 0.0)
    {
        discard;
    }
    
    return output;
}


