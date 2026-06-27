import express from "express";
// import fetch from "node-fetch";


const app = express();
app.use(express.json());

const image_urls = [
    "https://i.pinimg.com/736x/f8/cd/99/f8cd99988eb672aea847a6cd64bae234.jpg",
    "https://i.pinimg.com/736x/3c/63/99/3c6399c04806a0abded1002a500e95c2.jpg",
    "https://i.pinimg.com/736x/a0/06/4b/a0064bede84bb912992ccc86e20dd153.jpg", 
    "https://i.pinimg.com/736x/75/4d/13/754d13a11e445be64e33d0d8568cf973.jpg"
]


const getDistance = (lat, lon) => {
console.log(`${lat} ${lon}`);
}

app.get("/", async (req, res)=> {

    const ip = req.query.ip || req.headers['x-forwarded-for'] || req.socket.remoteAddress || null;
    const random = Math.floor(Math.random() * image_urls.length);
    const image = image_urls[random];
    const ip_details = await fetch(`http://ip-api.com/json/${ip}?fields=query,status,message,continent,continentCode,country,countryCode,regionName,region,city,district,zip,lat,lon,timezone,offset,currency,asname,isp,org,as,reverse,mobile,proxy,hosting`);
    const ip_details_json = await ip_details.json();


    const lat = ip_details_json.lat;
    const lon = ip_details_json.lon;
    res.json({ lat, lon });
//     const response = await fetch(image);


//     if(!response.ok){
//         return res.status(500).json({
//             success: false,
//             message: "Failed to fetch image"
//         });
//     }

//     const content_type = response.headers.get("content-type") || "image/jpeg";
//     const array_buffer = await response.arrayBuffer();
//     const buffer = Buffer.from(array_buffer);

//     res.setHeader("Content-Type", content_type);
//     res.send(buffer);
})

app.listen(3000, ()=> {
    console.log(`Sever running on 3000`);
})