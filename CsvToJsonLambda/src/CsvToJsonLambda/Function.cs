using Amazon.Lambda.Core;
using Amazon.S3;
using Amazon.S3.Model;
using Amazon.Lambda.S3Events;
using CsvHelper;
using Newtonsoft.Json;
using System.Globalization;


// Assembly attribute to enable the Lambda function's JSON input to be converted into a .NET class.
[assembly: LambdaSerializer(typeof(Amazon.Lambda.Serialization.SystemTextJson.DefaultLambdaJsonSerializer))]

namespace CsvToJsonLambda;

public class Function
{

    /// <summary>
    /// A simple function that takes a string and does a ToUpper
    /// </summary>
    /// <param name="input">The event for the Lambda function handler to process.</param>
    /// <param name="context">The ILambdaContext that provides methods for logging and describing the Lambda environment.</param>
    /// <returns></returns>
    private readonly IAmazonS3 _s3Client = new AmazonS3Client();
    public async Task FunctionHandler(S3Event s3Event, ILambdaContext context)
    {
        if (s3Event?.Records == null || !s3Event.Records.Any())
        {
            context.Logger.LogLine("Keine S3-Ereignisaufzeichnung gefunden.");
            return;
        }

        var record = s3Event.Records.First();


        string sourceBucket = record.S3.Bucket.Name;
        string objectKey = record.S3.Object.Key;
        string destinationBucket = "download-bucket-json-lmt-gbs"; // Ziel-Bucket hier anpassen

        try
        {
            // CSV-Datei aus S3 herunterladen
            var response = await _s3Client.GetObjectAsync(sourceBucket, objectKey);
            using var reader = new StreamReader(response.ResponseStream);

            using var csv = new CsvReader(reader, CultureInfo.InvariantCulture);

            // CSV in JSON umwandeln
            var records = csv.GetRecords<dynamic>();
            string jsonContent = JsonConvert.SerializeObject(records, Formatting.Indented);

            // JSON in Ziel-Bucket hochladen
            var putRequest = new PutObjectRequest
            {
                BucketName = destinationBucket,
                Key = Path.ChangeExtension(objectKey, ".json"),
                ContentBody = jsonContent
            };
            await _s3Client.PutObjectAsync(putRequest);

            context.Logger.LogLine($"Datei {objectKey} wurde erfolgreich in {destinationBucket} umgewandelt und hochgeladen.");
        }
        catch (Exception ex)
        {
            context.Logger.LogLine($"Fehler bei der Verarbeitung der Datei {objectKey}: {ex.Message}");
        }
    }
}
