import express from "express";
import fetch from "node-fetch";


const app = express();
app.use(express.json());

app.get("/", (req, res)=> {
    res.json({
        success: true
    })
})

app.listen(3000, ()=> {
    console.log(`Sever running on 3000`);
})