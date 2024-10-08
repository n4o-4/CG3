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
    float4 color; // ���C�g�̐F
    float3 position; // ���C�g�̈ʒu
    float intensity; // �P�x
    float radius; // ���C�g�̓͂��ő勗��
    float decay; // ������
};

struct SpotLight
{
    float4 color; // ���C�g�̐F
    float3 position; // ���C�g�̈ʒu
    float intensity; // �P�x
    float3 direction; // �X�|�b�g���C�g�̕���
    float distance; // ���C�g�̓͂��ő勗��
    float decay; // ������
    float cosAngle; // �X�|�b�g���C�g�̗]��
    float cosFalloffStart;
};

struct Camera
{
    float3 worldPosition;
};

ConstantBuffer<Material> gMaterial : register(b0);

ConstantBuffer<DirectionLight> gDirectionalLight : register(b1);

ConstantBuffer<Camera> gCamera : register(b2);

ConstantBuffer<PointLight> gPointLight : register(b3);

ConstantBuffer<SpotLight> gSpotLight : register(b4);

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
        
        /*-----------------------------------
        directinalLight�̏���
        -----------------------------------*/
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
        
        // ���ʔ���
        float3 specularDirectionLight = gDirectionalLight.color.rgb * gDirectionalLight.intensity * specularPow;// * float3(1.0f, 1.0f, 1.0f);
    
        // �g�U����
        float3 diffuseDirectionLight = gMaterial.color.rgb * textureColor.rgb * gDirectionalLight.color.rgb * cos * gDirectionalLight.intensity;
        
        /*--------------------------------
        PointLight�̏���
        ---------------------------------*/
        float distance = length(gPointLight.position - input.worldPosition); // �|�C���g���C�g�ւ̋���
        
        float factor = pow(saturate(-distance / gPointLight.radius + 1.0),gPointLight.decay);

        float3 pointLightDirection = normalize(input.worldPosition - gPointLight.position);
        
        NdotL = dot(normalize(input.normal), -pointLightDirection);
        
        cos = pow(NdotL * 0.5f + 0.5f, 2.0f);
        
        reflectLight = reflect(pointLightDirection, normalize(input.normal));
        
        toEye = normalize(gCamera.worldPosition - input.worldPosition);
        
        halfVector = normalize(-pointLightDirection + toEye);
        
        NDotH = dot(normalize(input.normal), halfVector);
        
        specularPow = pow(saturate(NDotH), gMaterial.shininess);
        
        //���ʔ���

        float3 specularPointLight = gPointLight.color.rgb * gPointLight.intensity * specularPow * factor;// * float3(1.0f, 1.0f, 1.0f);
    
        // �g�U����
        float3 diffusePointLight = gMaterial.color.rgb * textureColor.rgb * gPointLight.color.rgb * cos * gPointLight.intensity * factor;
        
        /*-------------------------------
        SpotLight�̏���
        -------------------------------*/
        
        distance = length(gSpotLight.position - input.worldPosition); // �|�C���g���C�g�ւ̋���
        
        float attenuationFactor = pow(saturate(-distance / gSpotLight.distance + 1.0), gSpotLight.decay);
        
        float3 spotLightDirectionOnSurface = normalize(input.worldPosition - gSpotLight.position);
        
        float cosAngle = dot(spotLightDirectionOnSurface, gSpotLight.direction);
        
        float falloffFactor = saturate((cosAngle - gSpotLight.cosAngle) / (gSpotLight.cosFalloffStart - gSpotLight.cosAngle));
        
        /*--------------------------------------------*/
        
        NdotL = dot(normalize(input.normal), -gSpotLight.direction);
        
        cos = pow(NdotL * 0.5f + 0.5f, 2.0f);
        
        reflectLight = reflect(gSpotLight.direction, normalize(input.normal));
        
        toEye = normalize(gCamera.worldPosition - input.worldPosition);
        
        halfVector = normalize(-gSpotLight.direction + toEye);
        
        NDotH = dot(normalize(input.normal), halfVector);
        
        specularPow = pow(saturate(NDotH), gMaterial.shininess);
        
        // ���ʔ���
        float3 specularSpotLight = gSpotLight.color.rgb * gSpotLight.intensity * specularPow * falloffFactor * attenuationFactor; // * float3(1.0f, 1.0f, 1.0f);
    
        // �g�U����
        float3 diffuseSpotLight = gMaterial.color.rgb * textureColor.rgb * gSpotLight.color.rgb * gSpotLight.intensity * falloffFactor * attenuationFactor * cos;
        
        /*--------------------------------------------*/
        
        // �g�U���ˁ{���ʔ���
        output.color.rgb = diffuseDirectionLight + specularDirectionLight + diffusePointLight + specularPointLight + diffuseSpotLight + specularSpotLight;
        
        // �A���t�@�͍��܂œ���
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


